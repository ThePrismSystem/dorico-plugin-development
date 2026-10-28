"""Each example, run in Dorico on a scratch copy of the sample, then checked.

    python tests/dorico/test_examples.py              every example
    python tests/dorico/test_examples.py -k colour    those whose name matches

Each row: name, the example and its check (paths from the repository root), whether to run it twice (read-only
examples, to show Dorico's one Lua state doesn't change what they do), and any args the check needs. A row can also
name a case to run first (to select notes, say) and steps to take afterwards on the same copy: a command sent through
the Remote API, as a user pressing a key would, or another example with its own check.
"""
import sys
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import harness  # noqa: E402

FUNDAMENTALS = "examples/fundamentals/"
RECIPES = "examples/recipes/"
CHECKS = "tests/dorico/checks/"
READ_COLOURS = FUNDAMENTALS + "04-noteheads-and-colours.lua"

EXAMPLES = []


def row(name, example, twice=False, args=None, check=None, before=None, after=()):
    EXAMPLES.append({"name": name, "example": example, "check": check or CHECKS + Path(example).name,
                     "twice": twice, "args": args or {}, "before": before, "after": list(after)})


def then_check(check, example=None):
    """A step after the example: run another example (or none) on the same copy, and a check."""
    return {"example": example, "check": CHECKS + check}


def then_command(command):
    return {"command": command}


row("hello", FUNDAMENTALS + "01-hello.lua", twice=True)
row("walk_the_score", FUNDAMENTALS + "02-walk-the-score.lua", twice=True)
row("read_notes", FUNDAMENTALS + "03-read-notes.lua", twice=True)
row("noteheads_and_colours", FUNDAMENTALS + "04-noteheads-and-colours.lua", twice=True)
row("names_from_the_text_export", FUNDAMENTALS + "05-names-from-the-text-export.lua", twice=True)
row("commands", FUNDAMENTALS + "06-commands.lua",
    after=[then_command("Edit.Undo"), then_check("06-commands.undone.lua")])
row("act_on_the_selection", FUNDAMENTALS + "07-act-on-the-selection.lua",
    before={"case": "case_select.lua", "args": {"player": "Violin, solo & tutti", "pos": 0, "extend": 1}})
row("act_on_nothing_selected", FUNDAMENTALS + "07-act-on-the-selection.lua",
    check=CHECKS + "07-act-on-the-selection.none.lua")
row("select_by_id", FUNDAMENTALS + "08-select-by-id.lua",
    after=[then_check("08-select-by-id.coloured.lua", READ_COLOURS), then_command("Edit.Undo"),
           then_check("08-select-by-id.undone.lua", READ_COLOURS)])


class Examples(unittest.TestCase):
    pass


def make_test(spec):
    def test(self):
        before = spec["before"]
        first, first_args = (before["case"], before.get("args")) if before else \
            ("case_example.lua", harness.example_args(spec))
        with harness.scratch(self, first, args=first_args) as (client, _):
            if before:
                harness.run_more(self, client, "case_example.lua", harness.example_args(spec))
            for step in spec["after"]:
                if "command" in step:
                    client.command(step["command"])
                else:
                    harness.run_more(self, client, "case_example.lua", harness.example_args(step))
    return test


for spec in EXAMPLES:
    setattr(Examples, "test_" + spec["name"], make_test(spec))


if __name__ == "__main__":
    unittest.main()
