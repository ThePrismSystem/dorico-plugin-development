"""The object-model reference covers what the registry scan found: every class in docs/reference/members.json has a
section on a page, every member is listed in its class's section, and every class with a page of its own (all but
other-classes.md) has a definition in types/dorico.lua."""
import json
import re
import shutil
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SECTION = re.compile(r"^## `([^`]+)`\s*$", re.M)


def sections(ref):
    """{class: (page name, section text)} from every page in the reference folder."""
    found = {}
    for page in sorted(Path(ref).glob("*.md")):
        text = page.read_text(encoding="utf-8")
        marks = list(SECTION.finditer(text))
        for i, m in enumerate(marks):
            end = marks[i + 1].start() if i + 1 < len(marks) else len(text)
            found[m.group(1)] = (page.name, text[m.end():end])
    return found


def problems(root):
    root = Path(root)
    ref = root / "docs" / "reference"
    classes = json.loads((ref / "members.json").read_text(encoding="utf-8"))["classes"]
    found = sections(ref)
    types = (root / "types" / "dorico.lua").read_text(encoding="utf-8")
    out = []
    for cls, sides in sorted(classes.items()):
        if cls not in found:
            out.append(f"{cls}: no section")
            continue
        page, text = found[cls]
        for side in ("static", "instance"):
            for member in sides.get(side, []):
                if f"`{member}`" not in text:
                    out.append(f"{cls}: {member} not listed")
        if page != "other-classes.md" and not re.search(r"^---@class %s\b" % re.escape(cls.split(".", 1)[1]), types,
                                                         re.M):
            out.append(f"{cls}: no ---@class in types/dorico.lua")
    return out


class RuleTests(unittest.TestCase):
    def setUp(self):
        self.root = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.root, True)
        (self.root / "docs" / "reference").mkdir(parents=True)
        (self.root / "types").mkdir()
        members = {"classes": {"DoCore.Flow": {"instance": ["voiceStreams", "__len"]}, "DoCore.Odd": {}}}
        (self.root / "docs" / "reference" / "members.json").write_text(json.dumps(members), encoding="utf-8")

    def write(self, flow_page, others="## `DoCore.Odd`\n\nNo member table.\n", types="---@class Flow\n"):
        (self.root / "docs" / "reference" / "flow.md").write_text(flow_page, encoding="utf-8")
        (self.root / "docs" / "reference" / "other-classes.md").write_text(others, encoding="utf-8")
        (self.root / "types" / "dorico.lua").write_text(types, encoding="utf-8")

    def test_a_complete_reference_passes(self):
        self.write("## `DoCore.Flow`\n\n| `voiceStreams` | `__len` |\n")
        self.assertEqual(problems(self.root), [])

    def test_every_class_has_an_entry(self):
        self.write("## `DoCore.Flow`\n\n| `voiceStreams` | `__len` |\n", others="")
        self.assertEqual(problems(self.root), ["DoCore.Odd: no section"])

    def test_every_member_is_listed(self):
        self.write("## `DoCore.Flow`\n\n| `voiceStreams` |\n")
        self.assertEqual(problems(self.root), ["DoCore.Flow: __len not listed"])

    def test_definitions_cover_the_documented_classes(self):
        self.write("## `DoCore.Flow`\n\n| `voiceStreams` | `__len` |\n", types="---@class FlowLike\n")
        self.assertEqual(problems(self.root), ["DoCore.Flow: no ---@class in types/dorico.lua"])


class ReferenceTests(unittest.TestCase):
    def test_the_reference_covers_the_scan(self):
        self.assertEqual(problems(ROOT), [])


if __name__ == "__main__":
    unittest.main()
