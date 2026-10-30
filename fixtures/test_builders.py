"""The fixture builders with Dorico stood in for: they save only the copy they built, and move it only once it has
closed."""
import importlib
import io
import sys
import tempfile
import unittest
from contextlib import ExitStack
from pathlib import Path
from unittest import mock

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(HERE.parent / "tools"))
import build_sample  # noqa: E402
import dws  # noqa: E402
import run_lua  # noqa: E402

BUILDERS = ["build_sample", "build_pickup", "build_texts", "build_cautionary", "build_parallels", "build_reading"]
COPY = 9


class Dorico:
    """Records commands. File.SaveAs writes the file; File.CloseProject closes the copy unless ignore_close."""

    def __init__(self, active=COPY, ignore_close=False):
        self.active, self.ignore_close, self.commands = active, ignore_close, []

    def connect(self):
        pass

    def close(self):
        pass

    def status(self):
        return {"hasScore": self.active is not None, "activeOpenScoreID": self.active}

    def command(self, cmd):
        self.commands.append(cmd)
        if cmd.startswith("File.SaveAs?File="):
            Path(cmd.split("=", 1)[1]).write_bytes(b"PK")
        if cmd == f"File.CloseProject?OpenScoreID={COPY}&Save=false" and not self.ignore_close and self.active == COPY:
            self.active = None
        return {"message": "response", "code": "kOK"}

    def saves(self):
        return [c for c in self.commands if c.startswith("File.SaveAs")]

    def closes(self):
        return [c for c in self.commands if c.startswith("File.CloseProject")]


class Quiet(unittest.TestCase):
    def setUp(self):
        folder = tempfile.TemporaryDirectory()
        self.addCleanup(folder.cleanup)
        self.folder = Path(folder.name)
        stack = ExitStack()
        self.addCleanup(stack.close)
        stack.enter_context(mock.patch.object(build_sample.time, "sleep"))
        stack.enter_context(mock.patch.object(sys, "stdout", io.StringIO()))
        stack.enter_context(mock.patch.object(build_sample, "wait_saved", side_effect=lambda path: path.exists()))
        self.stack = stack


class SaveAsTests(Quiet):
    def test_saves_and_closes_the_copy(self):
        dorico = Dorico()
        self.assertTrue(build_sample.save_as(dorico, COPY, self.folder / "sample.dorico"))
        self.assertEqual(len(dorico.saves()), 1)
        self.assertIsNone(dorico.active)

    def test_saves_nothing_when_another_project_is_active(self):
        # File.SaveAs goes to the active project: the user's own would be saved into the repository's folders.
        dorico = Dorico(active=4)
        with mock.patch.object(run_lua, "close_scratch", return_value=True) as close:
            self.assertFalse(build_sample.save_as(dorico, COPY, self.folder / "sample.dorico"))
        self.assertEqual(dorico.saves(), [])
        close.assert_called_once_with(dorico, COPY)

    def test_a_close_dorico_ignores_is_not_confirmed(self):
        # Saved under its new name, the copy's title no longer ends " in scratch", so no title says it is still open.
        dorico = Dorico(ignore_close=True)
        with mock.patch.object(run_lua, "window_titles", return_value=[]):
            self.assertFalse(build_sample.save_as(dorico, COPY, self.folder / "sample.dorico"))
        self.assertGreater(len(dorico.closes()), 1, "the close is tried again")


class BuilderTests(Quiet):
    def build(self, name, dorico):
        """The builder's main() with the finish script verified on COPY and Dorico as given; returns its exit code and
        whether it moved a file."""
        module = importlib.import_module(name)
        verified = {"ok": True, "checks": [], "facts": {"scratchVerified": True, "scratchScoreID": COPY}}
        with ExitStack() as stack:
            stack.enter_context(mock.patch.object(module, "BUILT", self.folder / f"{name}.dorico"))
            for maker in [getattr(module, m) for m in dir(module) if m.startswith("make_") and m.endswith("_xml")]:
                stack.enter_context(mock.patch.object(maker, "main"))
            stack.enter_context(mock.patch.object(dws, "DoricoClient", return_value=dorico))
            stack.enter_context(mock.patch.object(run_lua, "run", return_value=(0, verified, COPY)))
            stack.enter_context(mock.patch.object(run_lua, "close_scratch", return_value=True))
            stack.enter_context(mock.patch.object(run_lua, "window_titles", return_value=[]))
            moved = stack.enter_context(mock.patch.object(Path, "replace"))
            return module.main(), moved.called

    def test_no_builder_saves_another_project(self):
        for name in BUILDERS:
            with self.subTest(name):
                dorico = Dorico(active=4)
                code, moved = self.build(name, dorico)
                self.assertNotEqual(code, 0)
                self.assertEqual(dorico.saves(), [])
                self.assertFalse(moved)

    def test_no_builder_moves_a_copy_still_open(self):
        for name in BUILDERS:
            with self.subTest(name):
                code, moved = self.build(name, Dorico(ignore_close=True))
                self.assertNotEqual(code, 0)
                self.assertFalse(moved)


if __name__ == "__main__":
    unittest.main()
