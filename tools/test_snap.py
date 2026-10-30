"""tools/snap.py with Dorico stood in for: it zooms and turns pages only on the scratch copy."""
import os
import subprocess
import sys
import unittest
from unittest import mock

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import snap  # noqa: E402


class Client:
    def __init__(self, active):
        self.active, self.commands = active, []

    def status(self):
        return {"hasScore": True, "activeOpenScoreID": self.active}

    def command(self, cmd):
        self.commands.append(cmd)
        return {"message": "response", "code": "kOK"}


class SnapTests(unittest.TestCase):
    def test_nothing_is_sent_while_another_project_is_active(self):
        # the view commands go to whichever project is active, which may be the user's own
        client = Client(active=4)
        with mock.patch.object(snap.subprocess, "run") as ran, self.assertRaises(RuntimeError):
            snap.snap("out.png", 7, client=client)
        self.assertEqual(client.commands, [])
        ran.assert_not_called()

    def test_the_copy_is_shown_and_captured(self):
        client = Client(active=7)
        captured = subprocess.CompletedProcess([], 0, stdout="out.png\t800 x 600\tFull score in scratch\n", stderr="")
        with mock.patch.object(snap.subprocess, "run", return_value=captured), mock.patch.object(snap.time, "sleep"):
            snap.snap("out.png", 7, page=2, client=client)
        self.assertEqual(client.commands, ["View.ZoomWholePage", "Edit.GoToPage?Index=1"])


if __name__ == "__main__":
    unittest.main()
