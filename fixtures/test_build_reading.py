"""fixtures/build_reading.py with Dorico stood in for: each run after the first names the import it works on."""
import io
import os
import sys
import unittest
from unittest import mock

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_reading  # noqa: E402


class BuildReadingTests(unittest.TestCase):
    def test_the_part_colour_runs_only_on_the_import_it_was_given(self):
        # The import has no path, as any project never saved, so its id must go with it.
        finished = {"ok": True, "facts": {"scratchVerified": True, "scratchScoreID": 9,
                                          "deferred": [{"layoutId": 3, "eventId": 5}]}}
        runs = [(0, finished, 9), (0, {"ok": True, "facts": {}}, None)]
        with mock.patch.object(build_reading.make_reading_xml, "main"), \
                mock.patch.object(build_reading.dws, "DoricoClient"), \
                mock.patch.object(build_reading, "show"), \
                mock.patch.object(build_reading.build_sample, "save_and_verify", return_value=(0, None)), \
                mock.patch.object(build_reading.run_lua, "run", side_effect=runs) as run, \
                mock.patch.object(sys, "stdout", io.StringIO()):
            self.assertEqual(build_reading.main(), 0)
        part = run.call_args_list[1]
        self.assertEqual(part.kwargs["extra_args"]["expectScratch"], {"path": "", "openScoreID": 9})
        self.assertEqual(part.kwargs["extra_args"]["eventId"], 5)


if __name__ == "__main__":
    unittest.main()
