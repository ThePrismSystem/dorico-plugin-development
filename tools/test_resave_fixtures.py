import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import resave_fixtures as r  # noqa: E402


def entry(path, source="fixtures/build_sample.py"):
    version = path.split("/")[0]
    return {"path": path, "fileVersion": "1.0", "savedBy": version, "source": source, "credit": ""}


class PlanTests(unittest.TestCase):
    ENTRIES = [
        entry("6.0.22/Novello_Lilacs.dorico", "https://ancientgroove.co.uk/dorico/Novello_Lilacs.dorico.zip"),
        entry("6.2.20/sample.dorico"),
        entry("6.2.30/reading.dorico", "fixtures/build_reading.py"),
        entry("6.2.30/sample.dorico"),
    ]

    def test_resaves_our_own_fixtures_from_the_newest_version(self):
        self.assertEqual([e["path"] for e in r.to_resave(self.ENTRIES)],
                         ["6.2.30/reading.dorico", "6.2.30/sample.dorico"])

    def test_leaves_downloaded_projects_alone(self):
        self.assertNotIn("6.0.22/Novello_Lilacs.dorico", [e["path"] for e in r.to_resave(self.ENTRIES)])

    def test_the_new_entry_names_its_source(self):
        new = r.new_entry("6.3.0/sample.dorico", "1.1500", "6.3.0", "6.2.30/sample.dorico")
        self.assertEqual(new, {"path": "6.3.0/sample.dorico", "fileVersion": "1.1500", "savedBy": "6.3.0",
                               "source": "re-saved from fixtures/6.2.30/sample.dorico by tools/resave_fixtures.py",
                               "credit": ""})

    def test_the_manifest_stays_sorted(self):
        merged = r.merged(self.ENTRIES, [entry("6.3.0/sample.dorico"), entry("6.10.0/sample.dorico")])
        self.assertEqual([e["path"] for e in merged], sorted(e["path"] for e in merged))
        self.assertEqual(len(merged), 6)

    def test_refuses_a_version_that_has_a_folder(self):
        with tempfile.TemporaryDirectory() as d:
            (Path(d) / "6.2.30").mkdir()
            self.assertIn("6.2.30", r.refusal("6.2.30", Path(d)))
            self.assertIsNone(r.refusal("6.3.0", Path(d)))

    def test_writes_the_manifest_as_the_tests_expect(self):
        with tempfile.TemporaryDirectory() as d:
            path = Path(d) / "versions.json"
            r.write_manifest(path, self.ENTRIES)
            self.assertEqual(json.loads(path.read_text(encoding="utf-8")), self.ENTRIES)


if __name__ == "__main__":
    unittest.main()
