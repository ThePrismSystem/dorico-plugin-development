"""The docs' links work: every relative link in README.md and docs/ points at a file that exists, and every link to a
heading (#anchor) matches a heading in its file, by GitHub's rule for heading anchors."""
import re
import shutil
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LINK = re.compile(r"\[[^\]]*\]\(([^)\s]+)\)")
HEADING = re.compile(r"^#+\s+(.*)$", re.M)


def docs(root):
    """README.md and the Markdown under docs/, leaving out docs/superpowers (working notes, kept out of git)."""
    root = Path(root)
    found = [root / "README.md"] if (root / "README.md").exists() else []
    for path in sorted((root / "docs").rglob("*.md")) if (root / "docs").exists() else []:
        if "superpowers" not in path.relative_to(root).parts:
            found.append(path)
    return found


def slug(heading):
    """GitHub's anchor for a heading: lower case, punctuation dropped, spaces to hyphens."""
    text = re.sub(r"`", "", heading.strip().lower())
    text = re.sub(r"[^\w\- ]", "", text)
    return text.replace(" ", "-")


def anchors(path):
    return {slug(h) for h in HEADING.findall(path.read_text(encoding="utf-8"))}


def broken(root):
    """Every link that doesn't resolve, as "<file>: <link>"."""
    root = Path(root)
    found = []
    for path in docs(root):
        text = path.read_text(encoding="utf-8")
        # A link inside a code span or code block is an example, so it isn't checked.
        text = re.sub(r"```.*?```", "", text, flags=re.S)
        text = re.sub(r"`[^`\n]*`", "", text)
        for target in LINK.findall(text):
            if re.match(r"^[a-z]+:", target):
                continue
            file_part, _, anchor = target.partition("#")
            dest = (path.parent / file_part).resolve() if file_part else path
            name = path.relative_to(root).as_posix()
            if not dest.exists():
                found.append(f"{name}: {target}")
            elif anchor and dest.suffix == ".md" and anchor not in anchors(dest):
                found.append(f"{name}: {target}")
    return found


class RuleTests(unittest.TestCase):
    def setUp(self):
        self.root = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.root, True)
        (self.root / "docs").mkdir()
        (self.root / "docs" / "other.md").write_text("# Other\n\n## A heading, with `code`\n", encoding="utf-8")

    def write(self, text):
        (self.root / "README.md").write_text(text, encoding="utf-8")

    def test_good_links_pass(self):
        self.write("[o](docs/other.md) [h](docs/other.md#a-heading-with-code) [w](https://example.com) [s](#top)\n"
                   "# Top\n")
        self.assertEqual(broken(self.root), [])

    def test_a_missing_file_is_found(self):
        self.write("[gone](docs/gone.md)\n")
        self.assertEqual(broken(self.root), ["README.md: docs/gone.md"])

    def test_a_missing_anchor_is_found(self):
        self.write("[h](docs/other.md#no-such-heading)\n")
        self.assertEqual(broken(self.root), ["README.md: docs/other.md#no-such-heading"])

    def test_links_in_code_are_left_alone(self):
        self.write("`[x](nowhere.md)`\n\n```\n[y](nowhere.md)\n```\n")
        self.assertEqual(broken(self.root), [])


class DocsTests(unittest.TestCase):
    def test_links_resolve(self):
        self.assertEqual(broken(ROOT), [])


if __name__ == "__main__":
    unittest.main()
