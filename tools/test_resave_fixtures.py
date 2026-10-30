import io
import json
import shutil
import subprocess
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parent))
import dws  # noqa: E402
import resave_fixtures as r  # noqa: E402
import run_lua  # noqa: E402


def entry(path, source="fixtures/build_sample.py", resaved_from=None):
    version = path.split("/")[0]
    e = {"path": path, "fileVersion": "1.0", "savedBy": version, "source": source, "credit": ""}
    if resaved_from:
        e["resavedFrom"] = resaved_from
    return e


DOWNLOADED = "https://ancientgroove.co.uk/dorico/Novello_Lilacs.dorico.zip"


class PlanTests(unittest.TestCase):
    ENTRIES = [
        entry("6.0.22/Novello_Lilacs.dorico", DOWNLOADED),
        entry("6.2.20/sample.dorico"),
        entry("6.2.30/reading.dorico", "fixtures/build_reading.py"),
        entry("6.2.30/sample.dorico"),
    ]
    RESAVED = [
        entry("6.3.0/reading.dorico", "fixtures/build_reading.py", "6.2.30/reading.dorico"),
        entry("6.3.0/sample.dorico", resaved_from="6.2.30/sample.dorico"),
    ]

    def test_resaves_our_own_fixtures_from_the_newest_version(self):
        self.assertEqual([e["path"] for e in r.to_resave(self.ENTRIES)],
                         ["6.2.30/reading.dorico", "6.2.30/sample.dorico"])

    def test_leaves_downloaded_projects_alone(self):
        self.assertNotIn("6.0.22/Novello_Lilacs.dorico", [e["path"] for e in r.to_resave(self.ENTRIES)])

    def test_resaves_what_an_earlier_release_resaved(self):
        self.assertEqual([e["path"] for e in r.to_resave(self.ENTRIES + self.RESAVED)],
                         ["6.3.0/reading.dorico", "6.3.0/sample.dorico"])

    def test_a_newer_downloaded_project_doesnt_hide_ours(self):
        newer = entry("6.4.0/Faure_Dolly.dorico", "https://ancientgroove.co.uk/dorico/Faure_Dolly.dorico.zip")
        self.assertEqual([e["path"] for e in r.to_resave(self.ENTRIES + [newer])],
                         ["6.2.30/reading.dorico", "6.2.30/sample.dorico"])

    def test_the_new_entry_keeps_its_builder_and_names_its_source(self):
        new = r.new_entry("6.3.0/sample.dorico", "1.1500", "6.3.0", entry("6.2.30/sample.dorico"))
        self.assertEqual(new, {"path": "6.3.0/sample.dorico", "fileVersion": "1.1500", "savedBy": "6.3.0",
                               "source": "fixtures/build_sample.py", "resavedFrom": "6.2.30/sample.dorico",
                               "credit": ""})

    def test_the_manifest_stays_sorted(self):
        merged = r.merged(self.ENTRIES, [entry("6.3.0/sample.dorico"), entry("6.10.0/sample.dorico")])
        self.assertEqual([e["path"] for e in merged], sorted(e["path"] for e in merged))
        self.assertEqual(len(merged), 6)

    def test_refuses_a_version_whose_fixtures_are_listed(self):
        with tempfile.TemporaryDirectory() as d:
            self.assertIn("6.2.30", r.refusal("6.2.30", self.ENTRIES, ["sample.dorico"], Path(d)))
            self.assertIn("6.3.0", r.refusal("6.3.0", self.ENTRIES + self.RESAVED, ["sample.dorico"], Path(d)))
            self.assertIsNone(r.refusal("6.3.0", self.ENTRIES, ["sample.dorico"], Path(d)))

    def test_takes_a_version_that_has_only_downloaded_projects(self):
        with tempfile.TemporaryDirectory() as d:
            (Path(d) / "6.0.22").mkdir()
            (Path(d) / "6.0.22" / "Novello_Lilacs.dorico").write_bytes(b"PK")
            self.assertIsNone(r.refusal("6.0.22", self.ENTRIES, ["sample.dorico"], Path(d)))

    def test_refuses_to_overwrite_a_file(self):
        with tempfile.TemporaryDirectory() as d:
            (Path(d) / "6.3.0").mkdir()
            (Path(d) / "6.3.0" / "sample.dorico").write_bytes(b"PK")
            self.assertIn("sample.dorico", r.refusal("6.3.0", self.ENTRIES, ["reading.dorico", "sample.dorico"],
                                                     Path(d)))

    def test_writes_the_manifest_as_the_tests_expect(self):
        with tempfile.TemporaryDirectory() as d:
            path = Path(d) / "versions.json"
            r.write_manifest(path, self.ENTRIES)
            self.assertEqual(json.loads(path.read_text(encoding="utf-8")), self.ENTRIES)


def project(path, saved_by, file_version="1.1500"):
    """A stand-in for a saved project, with what fixture_versions reads from one."""
    with zipfile.ZipFile(path, "w") as z:
        z.writestr("supplementary_data/scoreinfo/scoreinfo.xml",
                   f"<scoreInfo><lastSavedVersion>{saved_by}</lastSavedVersion></scoreInfo>")
        if file_version:
            z.writestr("score.xml", f"<score><fileVersion>{file_version}</fileVersion></score>")


class MainTests(unittest.TestCase):
    """main() against a stand-in Dorico: each save writes a small project saved by self.version, unless self.how
    says otherwise for that file."""

    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.root = Path(tmp.name) / "fixtures"
        self.run_dir = Path(tmp.name) / "run"
        self.root.mkdir()
        self.entries = [entry("6.0.22/Novello_Lilacs.dorico", DOWNLOADED),
                        entry("6.2.30/reading.dorico", "fixtures/build_reading.py"),
                        entry("6.2.30/sample.dorico")]
        for e in self.entries:
            (self.root / e["path"]).parent.mkdir(exist_ok=True)
            project(self.root / e["path"], e["savedBy"])
        r.write_manifest(self.root / "versions.json", self.entries)
        self.version = "6.3.0"
        self.how = {}
        self.stdout = io.StringIO()
        for patcher in (mock.patch.object(r.fixture_versions, "FIXTURES", self.root),
                        mock.patch.object(run_lua, "RUN_DIR", self.run_dir),
                        mock.patch.object(run_lua, "run", side_effect=self.save),
                        mock.patch.object(dws, "DoricoClient"),
                        mock.patch.object(r.subprocess, "run", return_value=subprocess.CompletedProcess([], 0)),
                        mock.patch.object(sys, "stdout", self.stdout)):
            patcher.start()
        self.addCleanup(mock.patch.stopall)

    def save(self, script, open_file=None, extra_args=None, client=None, timeout=None):
        how = self.how.get(Path(open_file).name)
        if how == "timeout":
            raise TimeoutError(f"{Path(open_file).name} did not open within 60s")
        if how == "fail":
            return 2, None, None
        project(Path(extra_args["out"]), self.version, None if how == "unreadable" else "1.1500")
        return 0, {"ok": True}, 7

    def manifest(self):
        return json.loads((self.root / "versions.json").read_text(encoding="utf-8"))

    def assert_nothing_kept(self):
        self.assertFalse((self.root / self.version).exists())
        self.assertEqual(self.manifest(), self.entries)

    def test_saves_into_a_folder_for_the_new_version(self):
        self.assertEqual(r.main([]), 0)
        self.assertEqual(sorted(p.name for p in (self.root / "6.3.0").iterdir()), ["reading.dorico", "sample.dorico"])
        new = [e for e in self.manifest() if e["savedBy"] == "6.3.0"]
        self.assertEqual(new, [r.new_entry("6.3.0/reading.dorico", "1.1500", "6.3.0", self.entries[1]),
                               r.new_entry("6.3.0/sample.dorico", "1.1500", "6.3.0", self.entries[2])])
        self.assertEqual(list((self.run_dir / "resave").iterdir()), [])

    def test_the_next_release_saves_them_again(self):
        self.assertEqual(r.main([]), 0)
        self.version = "6.4.0"
        self.assertEqual(r.main([]), 0)
        later = [e for e in self.manifest() if e["savedBy"] == "6.4.0"]
        self.assertEqual([e["resavedFrom"] for e in later], ["6.3.0/reading.dorico", "6.3.0/sample.dorico"])
        self.assertEqual([e["source"] for e in later], ["fixtures/build_reading.py", "fixtures/build_sample.py"])

    def test_refuses_a_version_already_saved(self):
        self.version = "6.2.30"
        self.assertEqual(r.main([]), 1)
        self.assertEqual(self.manifest(), self.entries)

    def test_a_failed_save_keeps_nothing(self):
        self.how["sample.dorico"] = "fail"
        self.assertEqual(r.main([]), 2)
        self.assert_nothing_kept()
        self.assertIn("could not save 6.2.30/sample.dorico", self.stdout.getvalue())

    def test_a_save_that_times_out_keeps_nothing(self):
        self.how["reading.dorico"] = "timeout"
        self.assertEqual(r.main([]), 2)
        self.assert_nothing_kept()

    def test_an_earlier_runs_file_is_not_taken_for_a_failed_save(self):
        # resave.lua can time out after app:save wrote its file
        (self.run_dir / "resave").mkdir(parents=True)
        project(self.run_dir / "resave" / "sample.dorico", "6.3.0")
        self.how["sample.dorico"] = "fail"
        self.assertEqual(r.main([]), 2)
        self.assert_nothing_kept()

    def test_a_copy_without_a_file_version_keeps_nothing(self):
        self.how["sample.dorico"] = "unreadable"
        with self.assertRaises(ValueError):
            r.main([])
        self.assert_nothing_kept()

    def test_a_failed_move_takes_back_the_folder(self):
        moves = []

        def move(source, target):
            moves.append(target)
            if len(moves) == 2:
                raise OSError("disk full")
            return shutil.copyfile(source, target)

        with mock.patch.object(r.shutil, "move", side_effect=move), self.assertRaises(OSError):
            r.main([])
        self.assert_nothing_kept()

    def test_a_downloaded_project_of_the_new_version_stays(self):
        downloaded = entry("6.3.0/Faure_Dolly.dorico", "https://ancientgroove.co.uk/dorico/Faure_Dolly.dorico.zip")
        (self.root / "6.3.0").mkdir()
        project(self.root / downloaded["path"], "6.3.0")
        self.entries = r.merged(self.entries, [downloaded])
        r.write_manifest(self.root / "versions.json", self.entries)
        with mock.patch.object(r.shutil, "move", side_effect=OSError("disk full")), self.assertRaises(OSError):
            r.main([])
        self.assertEqual([p.name for p in (self.root / "6.3.0").iterdir()], ["Faure_Dolly.dorico"])
        self.assertEqual(self.manifest(), self.entries)
        self.assertEqual(r.main([]), 0)
        self.assertEqual(sorted(p.name for p in (self.root / "6.3.0").iterdir()),
                         ["Faure_Dolly.dorico", "reading.dorico", "sample.dorico"])

    def test_a_failed_example_is_named_and_fails_the_run(self):
        shipped = self.run_dir / "inputs" / "shipped"
        shipped.mkdir(parents=True)
        for name in ("Bach.dorico", "Smith.dorico"):
            project(shipped / name, "6.2.0")
        self.how["Smith.dorico"] = "fail"
        self.assertEqual(r.main([]), 2)
        self.assertIn("could not save " + str(shipped / "Smith.dorico"), self.stdout.getvalue())
        self.assertEqual([p.name for p in (self.run_dir / "inputs" / "6.3.0").iterdir()], ["Bach.dorico"])
        self.assertEqual(len([e for e in self.manifest() if e["savedBy"] == "6.3.0"]), 2, "the fixtures still count")


if __name__ == "__main__":
    unittest.main()
