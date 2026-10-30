"""The in-Dorico suites' own helpers (tests/dorico/harness.py and test_examples.py), with Dorico stood in for."""
import subprocess
import sys
import unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parent / "dorico"))
import harness  # noqa: E402
import test_examples as examples  # noqa: E402


class Client:
    """Answers kOK to every command and reports active as the active project."""

    def __init__(self, active):
        self.active = active
        self.sent = []

    def settle(self, quiet=2.0, limit=30.0):
        return True

    def status(self):
        return {"hasScore": True, "activeOpenScoreID": self.active}

    def request(self, msg, expect=None):
        self.sent.append(msg["command"])
        return {"message": "response", "code": "kOK"}


class SendTests(unittest.TestCase):
    def test_a_command_goes_to_the_scratch_copy(self):
        client = Client(active=7)
        examples.send(self, client, 7, "Edit.Undo")
        self.assertEqual(client.sent, ["Edit.Undo"])

    def test_nothing_is_sent_when_another_project_is_active(self):
        # A user who clicks into their own project during the run would have their edits undone.
        client = Client(active=8)
        with self.assertRaises(AssertionError):
            examples.send(self, client, 7, "Edit.Undo")
        self.assertEqual(client.sent, [])


class ScratchTests(unittest.TestCase):
    def scratch(self, closed):
        verified = {"ok": True, "checks": [], "facts": {"scratchVerified": True, "scratchScoreID": 7}}
        with mock.patch.object(harness.dws, "DoricoClient"), \
                mock.patch.object(harness.run_lua, "run", return_value=(0, verified, 7)), \
                mock.patch.object(harness.run_lua, "close_scratch", return_value=closed) as close:
            with harness.scratch(self, "case_open.lua"):
                pass
        close.assert_called_once()

    def test_a_copy_that_closes_passes(self):
        self.scratch(closed=True)

    def test_a_copy_left_open_fails_this_test_not_the_next(self):
        with self.assertRaises(AssertionError):
            self.scratch(closed=False)


class AnswerTimeoutTests(unittest.TestCase):
    """click.ps1 can search Dorico's UI Automation tree, which can stall for minutes; a call that takes too long is
    a failed answer."""

    def setUp(self):
        patcher = mock.patch.object(harness.subprocess, "run", side_effect=subprocess.TimeoutExpired("powershell", 1))
        self.ran = patcher.start()
        self.addCleanup(patcher.stop)
        for name in ("wait_for", "open_windows"):
            patcher = mock.patch.object(harness.run_lua, name, return_value=True)
            patcher.start()
            self.addCleanup(patcher.stop)

    def assert_timed(self):
        for call in self.ran.call_args_list:
            self.assertIsNotNone(call.kwargs.get("timeout"), call.args[0])

    def test_click(self):
        self.assertFalse(harness.click("Note names", "OK"))
        self.assert_timed()

    def test_fill(self):
        self.assertFalse(harness.answer("Ask and report", "OK", "Hello"))
        self.assert_timed()

    def test_setfield(self):
        self.assertFalse(harness.answer_form("Note names", "OK", [("check", 0, True)]))
        self.assert_timed()


if __name__ == "__main__":
    unittest.main()
