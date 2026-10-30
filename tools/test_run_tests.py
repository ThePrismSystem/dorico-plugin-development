"""tools/run_tests.py's own helpers."""
import io
import os
import shutil
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import run_tests  # noqa: E402


class FindLuaTests(unittest.TestCase):
    def test_only_lua_5_2_is_taken(self):
        # a plain "lua" on the PATH may be 5.3 or 5.4, whose integers and libraries differ
        versions = {"lua52": None, "lua5.2": None, "lua": "Lua 5.4"}
        with mock.patch.object(run_tests, "LUA_CANDIDATES", ["lua52", "lua5.2", "lua"]), \
                mock.patch("shutil.which", side_effect=lambda c: c if versions.get(c) else None), \
                mock.patch.object(run_tests, "lua_version", side_effect=lambda exe: versions[exe]):
            self.assertIsNone(run_tests.find_lua())
        versions["lua"] = "Lua 5.2"
        with mock.patch.object(run_tests, "LUA_CANDIDATES", ["lua52", "lua5.2", "lua"]), \
                mock.patch("shutil.which", side_effect=lambda c: c if versions.get(c) else None), \
                mock.patch.object(run_tests, "lua_version", side_effect=lambda exe: versions[exe]):
            self.assertEqual(run_tests.find_lua(), "lua")


class SyntaxStepTests(unittest.TestCase):
    def setUp(self):
        self.luac = run_tests.run_lua.find_luac()
        if not self.luac:
            self.skipTest("no luac 5.2")
        self.folder = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.folder, True)

    def test_a_bad_file_is_reported_and_a_good_one_is_not(self):
        good, bad = self.folder / "good.lua", self.folder / "bad.lua"
        good.write_text("return 1\n")
        bad.write_text("local = 1\n")
        failures = run_tests.syntax_errors([good, bad], self.luac)
        self.assertEqual([Path(path).name for path, _ in failures], ["bad.lua"])

    def test_every_lua_file_in_the_checked_folders_is_found(self):
        (self.folder / "examples" / "recipes").mkdir(parents=True)
        (self.folder / "examples" / "recipes" / "r.lua").write_text("return 1\n")
        (self.folder / "spikes").mkdir()
        (self.folder / "spikes" / "s.lua").write_text("return 1\n")
        (self.folder / "elsewhere").mkdir()
        (self.folder / "elsewhere" / "e.lua").write_text("return 1\n")
        names = sorted(Path(p).name for p in run_tests.lua_files(self.folder))
        self.assertEqual(names, ["r.lua", "s.lua"])


class InputStepTests(unittest.TestCase):
    def test_without_lua_the_inputs_are_skipped(self):
        # the missing Lua has already failed its own step
        folder = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, folder, True)
        (folder / "inputs" / "shipped").mkdir(parents=True)
        (folder / "inputs" / "shipped" / "Bach.dorico").write_bytes(b"PK")
        with mock.patch.object(run_tests.run_lua, "RUN_DIR", folder), \
                mock.patch.object(run_tests.subprocess, "run", wraps=run_tests.subprocess.run) as ran, \
                mock.patch.object(sys, "stdout", io.StringIO()) as out:
            self.assertTrue(run_tests.input_checks(None))
        ran.assert_not_called()
        self.assertIn("inputs: skipped", out.getvalue())

    def test_asked_for_inputs_with_none_to_read_fails(self):
        # --inputs asks for them to be read, so reading nothing must not pass
        folder = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, folder, True)
        with mock.patch.object(run_tests.run_lua, "RUN_DIR", folder), \
                mock.patch.object(sys, "stdout", io.StringIO()) as out:
            self.assertFalse(run_tests.input_checks("lua52"))
        self.assertIn("FAIL  inputs: none in", out.getvalue())


if __name__ == "__main__":
    unittest.main()
