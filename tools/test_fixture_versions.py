import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import fixture_versions as fixtures  # noqa: E402


class VersionKeyTests(unittest.TestCase):
    def test_orders_by_number_not_text(self):
        self.assertLess(fixtures.version_key("6.2.30"), fixtures.version_key("6.10.0"))
        self.assertLess(fixtures.version_key("6.0.22"), fixtures.version_key("6.1.0"))

    def test_refuses_a_name_that_is_not_a_version(self):
        with self.assertRaises(ValueError):
            fixtures.version_key("notes")


class NewestTests(unittest.TestCase):
    def test_takes_the_highest_version_folder_holding_the_name(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            for v in ("6.2.30", "6.10.0", "6.9.1"):
                (root / v).mkdir()
            (root / "6.2.30" / "sample.dorico").write_bytes(b"a")
            (root / "6.9.1" / "sample.dorico").write_bytes(b"b")
            (root / "6.10.0" / "other.dorico").write_bytes(b"c")
            self.assertEqual(fixtures.newest("sample.dorico", root), root / "6.9.1" / "sample.dorico")

    def test_ignores_folders_that_are_not_versions(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            (root / "build").mkdir()
            (root / "build" / "sample.dorico").write_bytes(b"a")
            (root / "6.2.30").mkdir()
            (root / "6.2.30" / "sample.dorico").write_bytes(b"b")
            self.assertEqual(fixtures.newest("sample.dorico", root), root / "6.2.30" / "sample.dorico")

    def test_a_name_in_no_folder(self):
        with tempfile.TemporaryDirectory() as d:
            with self.assertRaises(FileNotFoundError):
                fixtures.newest("missing.dorico", Path(d))


class SavedFileTests(unittest.TestCase):
    def test_reads_which_dorico_saved_the_sample(self):
        sample = fixtures.newest("sample.dorico")
        self.assertEqual(fixtures.saved_by(sample), "6.2.30")
        self.assertEqual(fixtures.file_version(sample), "1.1452")


class ManifestTests(unittest.TestCase):
    def test_lists_exactly_the_projects_in_version_folders(self):
        listed = {e["path"] for e in fixtures.entries()}
        on_disk = {p.relative_to(fixtures.FIXTURES).as_posix()
                   for p in fixtures.FIXTURES.glob("*/*.dorico") if fixtures.is_version(p.parent.name)}
        self.assertEqual(listed, on_disk)

    def test_each_entry_matches_its_file(self):
        for e in fixtures.entries():
            path = fixtures.FIXTURES / e["path"]
            with self.subTest(e["path"]):
                self.assertEqual(path.parent.name, e["savedBy"], "a project sits in its saving version's folder")
                self.assertEqual(fixtures.saved_by(path), e["savedBy"])
                self.assertEqual(fixtures.file_version(path), e["fileVersion"])
                self.assertTrue(e["source"])
                self.assertIn("credit", e)

    def test_a_resaved_fixture_comes_from_an_older_copy_of_itself(self):
        for e in fixtures.entries():
            if "resavedFrom" in e:
                with self.subTest(e["path"]):
                    folder, name = e["resavedFrom"].split("/")
                    self.assertEqual(name, Path(e["path"]).name)
                    self.assertLess(fixtures.version_key(folder), fixtures.version_key(e["savedBy"]))
                    self.assertTrue(e["source"].startswith("fixtures/"), "it keeps its builder as its source")

    def test_manifest_is_sorted_json(self):
        text = (fixtures.FIXTURES / "versions.json").read_text(encoding="utf-8")
        entries = json.loads(text)
        self.assertEqual([e["path"] for e in entries], sorted(e["path"] for e in entries))


if __name__ == "__main__":
    unittest.main()
