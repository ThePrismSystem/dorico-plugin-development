"""The spike drivers close a project only when the probe confirmed it is the scratch copy."""
import importlib.util
import io
import sys
import unittest
from pathlib import Path
from unittest import mock

TOOLS = Path(__file__).resolve().parent
sys.path.insert(0, str(TOOLS))
import dws  # noqa: E402
import run_lua  # noqa: E402


def load(name):
    spec = importlib.util.spec_from_file_location(name, TOOLS.parent / "spikes" / f"{name}.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class MenuInPartTests(unittest.TestCase):
    def setUp(self):
        self.spike = load("w5_menu_in_part")
        for patcher in (mock.patch.object(dws, "DoricoClient"), mock.patch.object(self.spike, "show"),
                        mock.patch.object(sys, "stdout", io.StringIO())):
            patcher.start()
        self.addCleanup(mock.patch.stopall)

    def main(self, *runs):
        with mock.patch.object(run_lua, "run", side_effect=runs), \
                mock.patch.object(run_lua, "close_scratch") as close:
            code = self.spike.main()
        return code, close

    def test_an_unconfirmed_project_is_left_open(self):
        # after a failed check or a timeout, the id run() hands back can be the user's own project
        for first in ((2, {"ok": False, "facts": {"scratchVerified": False}}, 7), (2, None, 7)):
            with self.subTest(result=first[1]):
                code, close = self.main(first)
                self.assertEqual(code, 2)
                close.assert_not_called()

    def test_the_confirmed_copy_is_closed(self):
        found = {"scratchVerified": True, "partLayoutId": 3, "fullScoreId": 1, "path": "C:/T/scratch.dorico",
                 "note": {"eventId": 5}}
        code, close = self.main((0, {"ok": True, "facts": found}, 9), (0, {"ok": True, "facts": {}}, None))
        self.assertEqual(code, 0)
        self.assertEqual(close.call_args.args[1], 9)


if __name__ == "__main__":
    unittest.main()
