"""Each example, run in Dorico on a scratch copy of the sample, then checked.

    python tests/dorico/test_examples.py              every example
    python tests/dorico/test_examples.py -k colour    those whose name matches

Each row: name, the example and its check (paths from the repository root), whether to run it twice (read-only
examples, to show Dorico's one Lua state doesn't change what they do), and any args the check needs.
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

EXAMPLES = []


def row(name, example, twice=False, args=None):
    EXAMPLES.append({"name": name, "example": example, "check": CHECKS + Path(example).name, "twice": twice,
                     "args": args or {}})


row("hello", FUNDAMENTALS + "01-hello.lua", twice=True)
row("walk_the_score", FUNDAMENTALS + "02-walk-the-score.lua", twice=True)
row("read_notes", FUNDAMENTALS + "03-read-notes.lua", twice=True)
row("noteheads_and_colours", FUNDAMENTALS + "04-noteheads-and-colours.lua", twice=True)
row("names_from_the_text_export", FUNDAMENTALS + "05-names-from-the-text-export.lua", twice=True)


class Examples(unittest.TestCase):
    pass


def make_test(spec):
    def test(self):
        with harness.scratch(self, "case_example.lua", args=harness.example_args(spec)):
            pass
    return test


for spec in EXAMPLES:
    setattr(Examples, "test_" + spec["name"], make_test(spec))


if __name__ == "__main__":
    unittest.main()
