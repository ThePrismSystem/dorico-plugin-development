"""Rules every example follows, checked without Dorico: each guards for no project, selects by block ids from
stream.blockInstances, says in its header what it changes and how to undo it, and keeps copied helpers identical."""
import re
import shutil
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
HEADER_LINES = ("What it does:", "Changes:", "Undo:", "Builds on:")
BLOCK = re.compile(r"^-- helper: (\w+)\n(.*?)^-- end helper: \1$", re.M | re.S)


def examples(root):
    return sorted((Path(root) / "examples").rglob("*.lua"))


def header(text):
    """The comment lines at the top of a file, before its first line of code."""
    lines = []
    for line in text.splitlines():
        if not line.startswith("--"):
            break
        lines.append(line)
    return "\n".join(lines)


def blocks(text):
    return {m.group(1): m.group(2) for m in BLOCK.finditer(text)}


def problems(root):
    """Every rule an example breaks, as "<file>: <rule>"."""
    found, copies = [], {}
    for path in examples(root):
        text = path.read_text(encoding="utf-8")
        name = path.relative_to(root).as_posix()
        own = blocks(text)
        if "guard" not in own:
            found.append(f"{name}: no guard helper (the no-project check)")
        if "EventEdit.Select" in text and ("blockIdOf" not in own or re.search(r"-\s*1000\b", text)):
            found.append(f"{name}: selects without the blockIdOf helper")
        head = header(text)
        for line in HEADER_LINES:
            if line not in head:
                found.append(f"{name}: header has no '{line}' line")
        for helper, body in own.items():
            copies.setdefault(helper, {}).setdefault(body, []).append(name)
    for helper, versions in copies.items():
        if len(versions) > 1:
            found.append(f"helper {helper} differs between " + "; ".join(", ".join(v) for v in versions.values()))
    return found


GOOD = """-- One line on what it is.
-- What it does: prints hello.
-- Changes: nothing (read-only).
-- Undo: nothing to undo.
-- Builds on: nothing.

-- helper: guard
local function guard() return 1 end
-- end helper: guard
print(guard())
"""


class RuleTests(unittest.TestCase):
    def setUp(self):
        self.root = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.root, True)
        (self.root / "examples").mkdir()

    def write(self, name, text):
        (self.root / "examples" / name).write_text(text, encoding="utf-8")

    def test_a_good_example_breaks_no_rule(self):
        self.write("good.lua", GOOD)
        self.assertEqual(problems(self.root), [])

    def test_every_example_guards_for_no_project(self):
        self.write("bad.lua", GOOD.replace("-- helper: guard", "-- helper: other").replace("-- end helper: guard",
                                                                                            "-- end helper: other"))
        self.assertEqual(problems(self.root), ["examples/bad.lua: no guard helper (the no-project check)"])

    def test_selects_use_block_ids_from_block_instances(self):
        self.write("bad.lua", GOOD + 'app:doCommand("EventEdit.Select?EventBlockID=" .. (instance - 1000))\n')
        self.assertEqual(problems(self.root), ["examples/bad.lua: selects without the blockIdOf helper"])

    def test_changing_examples_say_how_to_undo(self):
        self.write("bad.lua", GOOD.replace("-- Undo: nothing to undo.\n", ""))
        self.assertEqual(problems(self.root), ["examples/bad.lua: header has no 'Undo:' line"])

    def test_helper_copies_are_identical(self):
        self.write("a.lua", GOOD)
        self.write("b.lua", GOOD.replace("return 1", "return 2"))
        self.assertEqual(len(problems(self.root)), 1)
        self.assertIn("helper guard differs between", problems(self.root)[0])


class ExamplesTests(unittest.TestCase):
    def test_the_examples_follow_the_rules(self):
        self.assertEqual(problems(ROOT), [])


if __name__ == "__main__":
    unittest.main()
