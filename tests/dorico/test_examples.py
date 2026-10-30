"""Each example, run in Dorico on a scratch copy of the sample or the reading fixture, then checked.

    python tests/dorico/test_examples.py              every example
    python tests/dorico/test_examples.py -k colour    those whose name matches

Each row: name, the example and its check (paths from the repository root), whether to run it twice (read-only
examples, to show Dorico's one Lua state doesn't change what they do), and any args the check needs. A row can also
name a case to run first (to select notes, say) and steps to take afterwards on the same copy: a command sent through
the Remote API, as a user pressing a key would, or another example with its own check.
"""
import json
import sys
import time
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import harness  # noqa: E402

FUNDAMENTALS = "examples/fundamentals/"
RECIPES = "examples/recipes/"
CHECKS = "tests/dorico/checks/"
READ_COLOURS = FUNDAMENTALS + "04-read-the-saved-copy.lua"

EXAMPLES = []


def row(name, example, twice=False, args=None, check=None, before=None, after=(), dialog=None, project=None):
    """dialog: {"window", "button", "text"?} for an example that waits on a box, or {"window", "button", "fields"}
    with fields as harness.answer_form takes them; the example then runs in the background while the test answers
    the box. project: None for the sample, "reading" for the reading fixture."""
    EXAMPLES.append({"name": name, "example": example, "check": check or CHECKS + Path(example).name,
                     "twice": twice, "args": args or {}, "before": before, "after": list(after), "dialog": dialog,
                     "project": harness.PROJECTS[project]})


def then_check(check, example=None, args=None):
    """A step after the example: run another example (or none) on the same copy, and a check."""
    return {"example": example, "check": CHECKS + check, "args": args or {}}


def then_dialog(check, example, dialog, args=None):
    """A step that runs an example again on the same copy, answering its box, then its check."""
    return {"example": example, "check": CHECKS + check, "dialog": dialog, "args": args or {}}


def then_command(command):
    """A step that sends a command through the Remote API, as a key press would; Dorico must answer kOK."""
    return {"command": command}


def request(client, command):
    """Dorico's reply to a command. Notices it pushes on its own (selectionchanged and the like) can come first, and
    the reply to an earlier command can still be queued, so the queue is read until it is quiet, and the reply is the
    next "response"."""
    client.settle(quiet=0.5, limit=10)
    return client.request({"message": "command", "command": command}, expect="response")


def send(test, client, command):
    reply = request(client, command)
    test.assertEqual(reply.get("code"), "kOK", f"{command}: {reply}")


def then_python(fn):
    """A step that checks from outside Dorico: fn(test, client, printed), printed being what the example printed."""
    return {"python": fn}


def then_rerun_last():
    """A step that presses Run Last Script (Ctrl+Shift+Alt+R) through the Remote API, waits for the rerun's result
    and checks it. Without the wait, a rerun Dorico hasn't reached yet can run nested inside the next case's
    commands."""
    def step(test, client, printed):
        result = harness.run_lua.RUN_DIR / "result.json"
        before = result.stat().st_mtime_ns if result.exists() else 0
        reply = request(client, "Script.RunLastScript")
        rewritten = harness.run_lua.wait_for(lambda: result.exists() and result.stat().st_mtime_ns != before, 30)
        # Checked after the wait: a failure closes the copy, and closing it under a rerun still to come crashed Dorico.
        test.assertEqual(reply.get("code"), "kOK", f"Script.RunLastScript: {reply}")
        test.assertTrue(rewritten, "Run Last Script wrote no result")
        harness.check(test, json.loads(result.read_text(encoding="utf-8")), "the rerun")
    return then_python(step)


def current_options(client, flow_ids):
    """The full score's flowHeadingBehaviour and each flow's final barline type, through the Remote API (Lua can't
    read options). Either can be missing from a reply while Dorico is busy."""
    layout = harness.options(client, "kLayout", "layoutID", 0).get("flowHeadingBehaviour")
    barlines = {f: harness.options(client, "kNotation", "flowID", f).get("barlineOptions.finalBarlineType")
                for f in flow_ids}
    return layout, barlines


def options_are(layout, flows, wait=10):
    """A step: the options settle at these values within wait seconds. Straight after an Edit.Undo, a read can come
    before Dorico has finished it, so the step reads again until the values match or the time is up."""
    def step(test, client, printed):
        deadline = time.time() + wait
        now = current_options(client, flows)
        while now != (layout, flows) and time.time() < deadline:
            time.sleep(0.5)
            now = current_options(client, flows)
        test.assertEqual(now, (layout, flows))
    return then_python(step)


row("hello", FUNDAMENTALS + "01-hello.lua", twice=True)
row("walk_the_score", FUNDAMENTALS + "02-walk-the-score.lua", twice=True)
row("read_notes", FUNDAMENTALS + "03-read-notes.lua", twice=True)
row("read_the_saved_copy", READ_COLOURS, twice=True)
# The edit before the run is an undo step of its own, so one Edit.Undo after 04 takes it back only if 04 added none.
row("read_the_saved_copy_adds_no_undo_step", READ_COLOURS, before={"case": "case_edit.lua"},
    after=[then_command("Edit.Undo"), then_check("04-read-the-saved-copy.undone.lua")])
row("names_and_titles", FUNDAMENTALS + "05-names-and-titles.lua", twice=True)
row("match_by_event_id", FUNDAMENTALS + "06-match-by-event-id.lua", twice=True)
row("values_per_layout", FUNDAMENTALS + "07-values-per-layout.lua", twice=True, project="reading")
row("text_lyrics_chords_dynamics", FUNDAMENTALS + "08-text-lyrics-chords-dynamics.lua", twice=True,
    project="reading")
row("text_flipped_in_the_full_score", FUNDAMENTALS + "08-text-lyrics-chords-dynamics.lua", project="reading",
    args={"below": "dolce"}, before={"case": "case_flip.lua", "args": {"words": "dolce"}})
row("bars_keys_and_times", FUNDAMENTALS + "09-bars-keys-and-times.lua", twice=True, project="reading")
row("bars_after_a_pickup", FUNDAMENTALS + "09-bars-keys-and-times.lua", project="pickup",
    check=CHECKS + "09-bars-keys-and-times.pickup.lua")
row("commands", FUNDAMENTALS + "10-commands.lua",
    after=[then_command("Edit.Undo"), then_check("10-commands.undone.lua")])
row("act_on_the_selection", FUNDAMENTALS + "11-act-on-the-selection.lua",
    before={"case": "case_select.lua", "args": {"player": "Violin, solo & tutti", "pos": 0, "extend": 1,
                                                "renameSecondFlow": True}},
    after=[then_command("Edit.Undo"), then_check("11-act-on-the-selection.undone.lua")])
row("act_on_nothing_selected", FUNDAMENTALS + "11-act-on-the-selection.lua",
    check=CHECKS + "11-act-on-the-selection.none.lua")
row("select_by_id", FUNDAMENTALS + "12-select-by-id.lua",
    after=[then_check("12-select-by-id.coloured.lua", READ_COLOURS), then_command("Edit.Undo"),
           then_check("12-select-by-id.undone.lua", READ_COLOURS)])
row("set_a_property_by_id", FUNDAMENTALS + "13-set-a-property-by-id.lua",
    after=[then_command("Edit.Undo"), then_check("13-set-a-property-by-id.undone.lua")])
row("add_notes_rests_text", FUNDAMENTALS + "14-add-notes-rests-text.lua",
    after=[then_command("Edit.Undo"), then_check("14-add-notes-rests-text.undone.lua")])
row("layout_and_notation_options", FUNDAMENTALS + "15-layout-and-notation-options.lua",
    after=[options_are("kNoFlowHeadings", {0: "kDouble", 1: "kFinal"}), then_command("Edit.Undo"),
           options_are("kAlwaysInsertHeadings", {0: "kFinal", 1: "kFinal"})])
row("flows_and_players", FUNDAMENTALS + "16-flows-and-players.lua",
    after=[then_command("Edit.Undo"), then_check("16-flows-and-players.undone.lua")])
OPEN_FIRST = {"case": "case_open.lua"}


def box(window, *fields):
    """A recipe's box answered with OK, after setting fields as harness.answer_form takes them."""
    return {"window": window, "button": "OK", "fields": list(fields)}


ANSWER = "Hello, world & Zoë"
row("ask_and_report", FUNDAMENTALS + "17-ask-and-report.lua", args={"answer": ANSWER}, before=OPEN_FIRST,
    dialog={"window": "Ask and report", "text": ANSWER, "button": "OK"})
row("ask_and_cancel", FUNDAMENTALS + "17-ask-and-report.lua", check=CHECKS + "17-ask-and-report.cancelled.lua",
    before=OPEN_FIRST, dialog={"window": "Ask and report", "button": "Cancel"})
# 18 can't run twice in one script run: the second run's Edit.Undo would be the run's second, and it takes back
# the earlier edit (seen when this row had twice=True).
row("undo", FUNDAMENTALS + "18-undo.lua", before={"case": "case_edit.lua"})
row("key_command", FUNDAMENTALS + "19-key-command.lua",
    after=[then_check("19-key-command.again.lua", FUNDAMENTALS + "19-key-command.lua")])
row("colour_by_pitch", RECIPES + "colour-by-pitch.lua",
    after=[then_check("colour-by-pitch.coloured.lua", READ_COLOURS), then_command("Edit.Undo"),
           then_check("12-select-by-id.undone.lua", READ_COLOURS)])
row("label_notes", RECIPES + "label-notes.lua",
    after=[then_command("Edit.Undo"), then_check("label-notes.undone.lua")])
row("chord_symbols", RECIPES + "chord-symbols.lua",
    after=[then_command("Edit.Undo"), then_check("chord-symbols.one-undo.lua")]
    + [then_command("Edit.Undo")] * 10 + [then_check("chord-symbols.undone.lua")])
row("chord_symbols_beside_existing_ones", RECIPES + "chord-symbols.lua",
    check=CHECKS + "chord-symbols.existing.lua", before={"case": "case_chord.lua"})
row("proofread", RECIPES + "proofread.lua", twice=True)
row("instrument_report", RECIPES + "instrument-report.lua", twice=True)
HOTKEY = RECIPES + "hotkey-colour-cycle.lua"
row("hotkey_colour_cycle", HOTKEY,
    before={"case": "case_select.lua", "args": {"player": "Violin, solo & tutti", "pos": 0, "extend": 1}},
    after=[then_rerun_last(), then_rerun_last(),
           then_check("hotkey-colour-cycle.third.lua"), then_python(lambda test, client, printed: time.sleep(4)),
           then_check("hotkey-colour-cycle.restart.lua", HOTKEY),
           then_check("hotkey-colour-cycle.coloured.lua", READ_COLOURS)])

PARALLELS = RECIPES + "parallel-fifths.lua"
PARALLELS_OK = box("Parallel fifths and octaves")
row("parallel_fifths", PARALLELS, project="parallels", before=OPEN_FIRST, dialog=PARALLELS_OK,
    after=[then_dialog("parallel-fifths.lua", PARALLELS, PARALLELS_OK, args={"before": ["default"]}),
           then_dialog("parallel-fifths.none.lua", PARALLELS,
                       box("Parallel fifths and octaves", ("check", 6, True)),
                       args={"removed": ["default"]})])
row("parallel_fifths_with_hidden_and_contrary", PARALLELS, project="parallels", before=OPEN_FIRST,
    args={"findings": ["default", "hiddenAndContrary"]},
    dialog=box("Parallel fifths and octaves", ("check", 0, True), ("check", 1, True)),
    after=[then_dialog("parallel-fifths.lua", PARALLELS, PARALLELS_OK,
                       args={"before": ["default", "hiddenAndContrary"]})])
row("parallel_fifths_undone", PARALLELS, project="parallels", before=OPEN_FIRST, dialog=PARALLELS_OK,
    after=[then_command("Edit.Undo"), then_check("parallel-fifths.none.lua")])
row("parallel_fifths_cancelled", PARALLELS, project="parallels", before=OPEN_FIRST,
    check=CHECKS + "parallel-fifths.none.lua", args={"cancelled": True},
    dialog={"window": "Parallel fifths and octaves", "button": "Cancel"})
NAMES = RECIPES + "note-names.lua"
NAMES_OK = box("Note names")
row("note_names", NAMES, project="reading", before=OPEN_FIRST, dialog=NAMES_OK,
    after=[then_dialog("note-names.lua", NAMES, NAMES_OK, args={"second": True}),
           then_dialog("note-names.none.lua", NAMES, box("Note names", ("check", 2, True)))])
row("note_names_at_sounding_pitch", NAMES, project="reading", before=OPEN_FIRST, args={"sounding": True},
    dialog=box("Note names", ("check", 1, False)))
row("note_names_undone", NAMES, project="reading", before=OPEN_FIRST, dialog=NAMES_OK,
    after=[then_command("Edit.Undo"), then_check("note-names.none.lua")])
row("note_names_cancelled", NAMES, project="reading", before=OPEN_FIRST, check=CHECKS + "note-names.none.lua",
    args={"cancelled": True}, dialog={"window": "Note names", "button": "Cancel"})
# The Players list is the third list: 1 is the flute, 2 the clarinet.
row("note_names_one_player_then_another", NAMES, project="reading", before=OPEN_FIRST,
    check=CHECKS + "note-names.two-players.lua", args={"players": ["Flute"]},
    dialog=box("Note names", ("choice", 2, 1)),
    after=[then_dialog("note-names.two-players.lua", NAMES,
                       box("Note names", ("choice", 2, 2)),
                       args={"players": ["Flute", "Clarinet (B{@flat@})"]})])
CAUTIONARY = RECIPES + "cautionary-accidentals.lua"
CAUTIONARY_OK = box("Cautionary accidentals")
row("cautionary_accidentals", CAUTIONARY, project="cautionary", before=OPEN_FIRST, dialog=CAUTIONARY_OK,
    after=[then_dialog("cautionary-accidentals.lua", CAUTIONARY, CAUTIONARY_OK, args={"kept": True}),
           then_dialog("cautionary-accidentals.none.lua", CAUTIONARY,
                       box("Cautionary accidentals", ("check", 3, True)),
                       args={"takenBack": 5})])
# Square brackets (the second item of the second list) and other instruments find the flute's B after the violin's
# B flat too; a run on the defaults then takes that one off and puts round brackets on the rest.
row("cautionary_accidentals_square_and_other_instruments", CAUTIONARY, project="cautionary", before=OPEN_FIRST,
    args={"findings": "otherInstruments", "value": "kSquareBrackets"},
    dialog=box("Cautionary accidentals", ("choice", 1, 1), ("check", 2, True)),
    after=[then_dialog("cautionary-accidentals.lua", CAUTIONARY, CAUTIONARY_OK, args={"takenBack": 1})])
row("cautionary_accidentals_undone", CAUTIONARY, project="cautionary", before=OPEN_FIRST, dialog=CAUTIONARY_OK,
    after=[then_command("Edit.Undo"), then_check("cautionary-accidentals.none.lua")])
row("cautionary_accidentals_cancelled", CAUTIONARY, project="cautionary", before=OPEN_FIRST,
    check=CHECKS + "cautionary-accidentals.none.lua", args={"cancelled": True},
    dialog={"window": "Cautionary accidentals", "button": "Cancel"})
FIND = RECIPES + "find-and-replace.lua"


def find_box(*fields):
    """The find and replace box answered with OK. Text fields: 0 find, 1 replace with, 2 from bar, 3 to bar. Tick
    boxes: 0 match case, 1 whole words, 2 Lua pattern. Lists: 0 mode (1 is Replace), 1 flows, 2 players."""
    return box("Find and replace", *fields)


def selection_kept(test, client, printed):
    test.assertTrue(client.status().get("hasSelection"), "the first match isn't selected")


REPLACE = ("choice", 0, 1)
# Deleting the selection shows which item is selected: the first match, the flute's staff text in bar 1.
row("find_and_replace_find", FIND, project="texts", before=OPEN_FIRST, args={"row": "find"},
    dialog=find_box(("text", 0, "dolce")),
    after=[then_python(selection_kept), then_command("Edit.Delete"),
           then_check("find-and-replace.none.lua", args={"gone": [1]})])
row("find_and_replace_found_nothing", FIND, project="texts", before=OPEN_FIRST,
    check=CHECKS + "find-and-replace.none.lua", args={"said": "Found nothing."},
    dialog=find_box(("text", 0, "zzz")))
row("find_and_replace_replacement_it_cant_work_out", FIND, project="texts", before=OPEN_FIRST,
    check=CHECKS + "find-and-replace.none.lua",
    args={"said": "The replacement couldn't be worked out: the pattern has no capture 3. Nothing changed."},
    dialog=find_box(REPLACE, ("text", 0, "dolce"), ("text", 1, "%3"), ("check", 2, True)))
row("find_and_replace_find_one_player_from_a_bar", FIND, project="texts", before=OPEN_FIRST,
    args={"row": "findSopranoFromBar2"}, dialog=find_box(("text", 0, "dolce"), ("choice", 2, 2), ("text", 2, "2")))
row("find_and_replace_replace", FIND, project="texts", before=OPEN_FIRST, args={"row": "replace"},
    dialog=find_box(REPLACE, ("text", 0, "dolce"), ("text", 1, "sweet"), ("check", 1, True)),
    after=[then_command("Edit.Undo"), then_check("find-and-replace.none.lua")])
row("find_and_replace_pattern", FIND, project="texts", before=OPEN_FIRST, args={"row": "pattern"},
    dialog=find_box(REPLACE, ("text", 0, "^(%a+) (sempre)$"), ("text", 1, "%2 %1"), ("check", 0, True),
                    ("check", 2, True)))
CHORD_UNDO_PRESSES = 2  # one press takes back too little (tried)
row("find_and_replace_chord_symbol", FIND, project="texts", before=OPEN_FIRST, args={"row": "chord"},
    dialog=find_box(REPLACE, ("text", 0, "Am"), ("text", 1, "Dm"), ("check", 0, True), ("check", 1, True)),
    after=[then_command("Edit.Undo")] * CHORD_UNDO_PRESSES + [then_check("find-and-replace.none.lua")])
row("find_and_replace_chord_symbol_dorico_cant_read", FIND, project="texts", before=OPEN_FIRST,
    args={"row": "chordUnreadable"},
    dialog=find_box(REPLACE, ("text", 0, "G7"), ("text", 1, "Xyzzy"), ("check", 0, True), ("check", 1, True)))
row("find_and_replace_cancelled", FIND, project="texts", before=OPEN_FIRST,
    check=CHECKS + "find-and-replace.none.lua", args={"cancelled": True},
    dialog={"window": "Find and replace", "button": "Cancel"})
# Flow 10 of the Somervell project has two texts "espress.": a plain one, and one with formatting inside it.
row("find_and_replace_leaves_formatted_text", FIND, project="somervell", before=OPEN_FIRST,
    check=CHECKS + "find-and-replace.somervell.lua",
    dialog=find_box(REPLACE, ("text", 0, "espress."), ("text", 1, "espressivo"), ("choice", 1, 10)))

class Examples(unittest.TestCase):
    pass


def run_answering(test, client, args, box):
    """Run case_example.lua in the background while answering the example's box, and give back the result."""
    run = harness.Background(lambda: harness.run_more(test, client, "case_example.lua", args, timeout=180,
                                                      expect_ok=False))
    if "fields" in box:
        answered = harness.answer_form(box["window"], box["button"], box["fields"])
    else:
        answered = harness.answer(box["window"], box["button"], box.get("text"))
    if not answered:
        # Dorico runs nothing else while the box is open, so close it before failing.
        harness.click(box["window"], "Cancel")
    result = harness.check(test, run.join(240), "case_example.lua")
    test.assertTrue(answered, f"couldn't answer the '{box['window']}' box")
    return result


def make_test(spec):
    def test(self):
        before = spec["before"]
        first, first_args = (before["case"], before.get("args")) if before else \
            ("case_example.lua", harness.example_args(spec))
        with harness.scratch(self, first, args=first_args, open_file=spec["project"]) as (client, result):
            if spec["dialog"]:
                result = run_answering(self, client, harness.example_args(spec), spec["dialog"])
            elif before:
                result = harness.run_more(self, client, "case_example.lua", harness.example_args(spec))
            printed = (result.get("facts") or {}).get("printed") or []
            for step in spec["after"]:
                if "command" in step:
                    send(self, client, step["command"])
                elif "python" in step:
                    step["python"](self, client, printed)
                elif "dialog" in step:
                    run_answering(self, client, harness.example_args(step), step["dialog"])
                else:
                    harness.run_more(self, client, "case_example.lua", harness.example_args(step))
    return test


for spec in EXAMPLES:
    setattr(Examples, "test_" + spec["name"], make_test(spec))


if __name__ == "__main__":
    unittest.main()
