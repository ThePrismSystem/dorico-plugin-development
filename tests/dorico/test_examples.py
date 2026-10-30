"""Each example, run in Dorico on a scratch copy of the sample, then checked.

    python tests/dorico/test_examples.py              every example
    python tests/dorico/test_examples.py -k colour    those whose name matches

Each row: name, the example and its check (paths from the repository root), whether to run it twice (read-only
examples, to show Dorico's one Lua state doesn't change what they do), and any args the check needs. A row can also
name a case to run first (to select notes, say) and steps to take afterwards on the same copy: a command sent through
the Remote API, as a user pressing a key would, or another example with its own check.
"""
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
    """dialog: {"window", "button", "text"?} for an example that waits on a box; the example then runs in the
    background while the test answers the box. project: None for the sample, "reading" for the reading fixture."""
    EXAMPLES.append({"name": name, "example": example, "check": check or CHECKS + Path(example).name,
                     "twice": twice, "args": args or {}, "before": before, "after": list(after), "dialog": dialog,
                     "project": harness.PROJECTS[project]})


def then_check(check, example=None):
    """A step after the example: run another example (or none) on the same copy, and a check."""
    return {"example": example, "check": CHECKS + check}


def then_command(command):
    return {"command": command}


def then_python(fn):
    """A step that checks from outside Dorico: fn(test, client, printed), printed being what the example printed."""
    return {"python": fn}


def then_rerun_last():
    """A step that presses Run Last Script (Ctrl+Shift+Alt+R) through the Remote API and waits for the rerun's
    result. Without the wait, a rerun Dorico hasn't reached yet can run nested inside the next case's commands."""
    def step(test, client, printed):
        result = harness.run_lua.RUN_DIR / "result.json"
        before = result.stat().st_mtime_ns if result.exists() else 0
        client.command("Script.RunLastScript")
        rewritten = harness.run_lua.wait_for(lambda: result.exists() and result.stat().st_mtime_ns != before, 30)
        test.assertTrue(rewritten, "Run Last Script wrote no result")
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
row("names_and_titles", FUNDAMENTALS + "05-names-and-titles.lua", twice=True)
row("match_by_event_id", FUNDAMENTALS + "06-match-by-event-id.lua", twice=True)
row("values_per_layout", FUNDAMENTALS + "07-values-per-layout.lua", twice=True, project="reading")
row("text_lyrics_chords_dynamics", FUNDAMENTALS + "08-text-lyrics-chords-dynamics.lua", twice=True,
    project="reading")
row("bars_keys_and_times", FUNDAMENTALS + "09-bars-keys-and-times.lua", twice=True, project="reading")
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


class Examples(unittest.TestCase):
    pass


def make_test(spec):
    def test(self):
        before = spec["before"]
        first, first_args = (before["case"], before.get("args")) if before else \
            ("case_example.lua", harness.example_args(spec))
        with harness.scratch(self, first, args=first_args, open_file=spec["project"]) as (client, result):
            if spec["dialog"]:
                box = spec["dialog"]
                run = harness.Background(lambda: harness.run_more(self, client, "case_example.lua",
                                                                  harness.example_args(spec), timeout=180,
                                                                  expect_ok=False))
                answered = harness.answer(box["window"], box["button"], box.get("text"))
                if not answered:
                    # Dorico runs nothing else while the box is open, so close it before failing.
                    harness.click(box["window"], "Cancel")
                result = harness.check(self, run.join(240), "case_example.lua")
                self.assertTrue(answered, f"couldn't answer the '{box['window']}' box")
            elif before:
                result = harness.run_more(self, client, "case_example.lua", harness.example_args(spec))
            printed = (result.get("facts") or {}).get("printed") or []
            for step in spec["after"]:
                if "command" in step:
                    client.command(step["command"])
                elif "python" in step:
                    step["python"](self, client, printed)
                else:
                    harness.run_more(self, client, "case_example.lua", harness.example_args(step))
    return test


for spec in EXAMPLES:
    setattr(Examples, "test_" + spec["name"], make_test(spec))


if __name__ == "__main__":
    unittest.main()
