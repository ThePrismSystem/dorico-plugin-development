"""The docs' links work: every relative link in README.md and docs/ points at a file that exists, and every link to a
heading (#anchor) matches a heading in its file, by GitHub's rule for heading anchors."""
import re
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LINK = re.compile(r"\[[^\]]*\]\(([^)\s]+)\)")
HEADING = re.compile(r"^#+\s+(.*)$", re.M)


def docs(root):
    """README.md and the Markdown under docs/, leaving out any git ignores (local notes)."""
    root = Path(root)
    out = subprocess.run(["git", "ls-files", "--others", "--ignored", "--exclude-standard", "--", "docs"], cwd=root,
                         capture_output=True, text=True)
    ignored = set(out.stdout.splitlines()) if out.returncode == 0 else set()
    found = [root / "README.md"] if (root / "README.md").exists() else []
    for path in sorted((root / "docs").rglob("*.md")) if (root / "docs").exists() else []:
        if path.relative_to(root).as_posix() not in ignored:
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


NUMBERED = re.compile(r"\[(\d\d)(?:-[^\]]*)?\]\(([^)\s]+)\)")


def mislabelled(root):
    """Every link labelled with an example's number ("[08]" or "[08-name]") whose target is another numbered example,
    as "<file>: <link>". A renumbering can update a target and leave its label behind."""
    root = Path(root)
    found = []
    for path in docs(root):
        text = re.sub(r"```.*?```", "", path.read_text(encoding="utf-8"), flags=re.S)
        for m in NUMBERED.finditer(text):
            name = m.group(2).split("#")[0].rsplit("/", 1)[-1]
            if re.match(r"^\d\d-", name) and not name.startswith(m.group(1) + "-"):
                found.append(f"{path.relative_to(root).as_posix()}: {m.group(0)}")
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

    def test_docs_git_ignores_are_left_alone(self):
        subprocess.run(["git", "init", "-q", str(self.root)], check=True)
        (self.root / ".git" / "info" / "exclude").write_text("docs/notes/\n", encoding="utf-8")
        (self.root / "docs" / "notes").mkdir()
        (self.root / "docs" / "notes" / "draft.md").write_text("[gone](gone.md)\n", encoding="utf-8")
        self.write("[o](docs/other.md)\n")
        self.assertEqual(broken(self.root), [])

    def test_a_numbered_label_names_its_target(self):
        (self.root / "docs" / "12-select.lua").write_text("", encoding="utf-8")
        self.write("[12](docs/12-select.lua) [12-select](docs/12-select.lua) [08](docs/12-select.lua)\n")
        self.assertEqual(mislabelled(self.root), ["README.md: [08](docs/12-select.lua)"])


class DocsTests(unittest.TestCase):
    def test_links_resolve(self):
        self.assertEqual(broken(ROOT), [])

    def test_numbered_labels_name_their_targets(self):
        self.assertEqual(mislabelled(ROOT), [])


if __name__ == "__main__":
    unittest.main()
