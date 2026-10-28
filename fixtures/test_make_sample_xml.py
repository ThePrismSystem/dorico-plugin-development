"""The sample project's MusicXML and expected contents, written from fixtures/sample_data.py."""
import os
import sys
import unittest
import xml.etree.ElementTree as ET

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_sample_xml  # noqa: E402
import sample_data  # noqa: E402


class SampleTests(unittest.TestCase):
    def setUp(self):
        self.expected = make_sample_xml.expected()

    def notes(self, player, flow=0):
        for p in self.expected["flows"][flow]["players"]:
            if p["name"] == player:
                return p["notes"]
        self.fail(f"no player {player}")

    def test_musicxml_parses(self):
        root = ET.fromstring(make_sample_xml.build_xml())
        self.assertEqual(len(root.findall("part")), len(sample_data.PARTS))
        self.assertEqual(root.find("work/work-title").text, sample_data.FLOW_TITLE)

    def test_expected_lists_every_note(self):
        # Flute: 4 + 2 + 3 (the tie makes bar 3's last note and bar 4's first one note) + 1 + 1 + 2 + 1
        self.assertEqual(len(self.notes("Flute")), 14)
        self.assertEqual(len([n for n in self.notes("Violin, solo & tutti") if n["grace"]]), 1)

    def test_a_tie_is_one_note(self):
        tied = [n for n in self.notes("Flute") if n["pos"] == 11]
        self.assertEqual(tied, [{"spelling": "C5", "pos": 11, "duration": 3, "grace": False}])

    def test_the_trumpet_sounds_a_tone_below_written(self):
        trumpet = self.notes("Trumpet Zoë (B{@flat@})")
        self.assertEqual(trumpet[0]["spelling"], "G4", "written A4")
        self.assertEqual(trumpet[3]["spelling"], "B4", "written C#5")

    def test_flute_has_one_note_below_range(self):
        low = [n for n in self.notes("Flute") if make_sample_xml.midi(n["spelling"]) < make_sample_xml.midi("C4")]
        self.assertEqual([n["spelling"] for n in low], ["A3"])
        self.assertEqual(self.expected["outOfRange"], [{"player": "Flute", "spelling": "A3", "bar": 2, "beat": 3}])

    def test_the_chords_and_the_parallel_fifth(self):
        self.assertEqual(self.expected["chords"], [{"bar": 1, "name": "C"}, {"bar": 2, "name": "Am"},
                                                   {"bar": 3, "name": "F"}, {"bar": 4, "name": "G7"}])
        self.assertEqual(self.expected["parallelFifths"], [{"player": "Piano", "bar": 6, "beat": 1}])

    def test_one_styled_note(self):
        self.assertEqual(self.expected["styled"]["notehead"], "noteheadset.diamondNoteheads")

    def test_the_second_flow(self):
        self.assertEqual(self.expected["flows"][1]["title"], sample_data.SECOND_FLOW_TITLE)
        self.assertEqual([n["spelling"] for n in self.notes("Flute", 1)], ["C5", "D5", "E5", "F5"])


if __name__ == "__main__":
    unittest.main()
