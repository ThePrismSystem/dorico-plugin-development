"""The reader inside Dorico, on a scratch copy of every fixture in fixtures/versions.json, older versions included.

    python tests/dorico/test_reader.py

Dorico opens a fixture an older version saved after a notice the runner answers, so each case also checks that the
event ids it lists are the ones in the file as committed.
"""
import sys
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(HERE.parents[1] / "tools"))
import fixture_versions  # noqa: E402
import harness  # noqa: E402


class ReaderTests(unittest.TestCase):
    def test_every_fixture_matches_lua(self):
        for entry in fixture_versions.entries():
            with self.subTest(entry["path"]):
                path = fixture_versions.FIXTURES / entry["path"]
                args = {"original": "fixtures/" + entry["path"], "colour": "#ff123456"}
                with harness.scratch(self, "case_reader.lua", args=args, open_file=path) as (_, result):
                    facts = result["facts"]
                    self.assertGreater(facts["matched"]["copy"], 0)
                    self.assertEqual(facts["fileVersion"], entry["fileVersion"])
                    print(f"{entry['path']}: {facts['matched']} in {facts['readSeconds']:.1f}s", flush=True)


if __name__ == "__main__":
    unittest.main()
