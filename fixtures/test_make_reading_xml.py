import sys
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import make_reading_xml as m  # noqa: E402


def parts():
    root = ET.fromstring(m.build_xml().split("\n", 2)[2])
    return {p.get("id"): p for p in root.findall("part")}, root


class MusicXmlTests(unittest.TestCase):
    def test_every_part_is_listed_and_written(self):
        written, root = parts()
        listed = [sp.get("id") for sp in root.find("part-list").findall("score-part")]
        self.assertEqual(listed, list(written))
        self.assertEqual(len(listed), len(m.PARTS))

    def test_every_bar_adds_up(self):
        written, _ = parts()
        for pid, part in written.items():
            for measure in part.findall("measure"):
                n = int(measure.get("number"))
                want = m.bar_length(n) * m.DIVISIONS
                voices = {}
                for note in measure.findall("note"):
                    if note.find("chord") is not None or note.find("grace") is not None:
                        continue
                    v = note.findtext("voice")
                    voices[v] = voices.get(v, 0) + int(note.findtext("duration"))
                for v, total in voices.items():
                    self.assertEqual(total, want, f"{pid} bar {n} voice {v}")

    def test_the_kinds_the_reader_needs(self):
        text = m.build_xml()
        for needle in ("<harmony>", '<lyric number="2">', "<syllabic>begin</syllabic>", "<extend/>",
                       "<time-modification>", "<grace", '<tied type="start"/>', '<wedge type="crescendo"',
                       "<words>dolce</words>", "<rehearsal>A</rehearsal>", "<metronome>", "<staccato/>",
                       "<accent/>", "<tenuto/>", "<string>", "<fret>", "<words>pizz.</words>",
                       "<fifths>1</fifths>", "<beats>3</beats>", "<staves>2</staves>", "<transpose>",
                       'font-weight="bold"'):
            self.assertIn(needle, text)


class ExpectedTests(unittest.TestCase):
    def test_two_flows_with_every_player(self):
        e = m.expected()
        self.assertEqual([f["title"] for f in e["flows"]], [m.FLOW_TITLE, m.SECOND_FLOW_TITLE])
        self.assertEqual([p["name"] for p in e["flows"][0]["players"]], [m.player_name(p) for p in m.PARTS])

    def test_positions_are_exact_fractions(self):
        flute = m.expected()["flows"][0]["players"][0]["notes"]
        self.assertIn("13/3", [n["pos"] for n in flute], "the triplet's second note")
        self.assertIn("1/3", [n["duration"] for n in flute])

    def test_a_tie_is_one_note(self):
        flute = m.expected()["flows"][0]["players"][0]["notes"]
        tied = [n for n in flute if n["pos"] == "11"]
        self.assertEqual(len(tied), 1)
        self.assertEqual(tied[0]["duration"], "3")

    def test_transposing_parts_list_sounding_pitch(self):
        clarinet = next(p for p in m.expected()["flows"][0]["players"] if p["name"] == m.player_name(m.CLARINET))
        self.assertEqual(clarinet["notes"][0]["spelling"], "D5", "written E5 on a B-flat clarinet")

    def test_lists_of_other_items(self):
        e = m.expected()
        self.assertEqual([k["pos"] for k in e["keys"]], ["0", "16"])
        self.assertEqual([(t["pos"], t["beats"]) for t in e["times"]], [("0", 4), ("24", 3)])
        self.assertIn({"flow": 1, "player": "Flute", "pos": "0", "words": "dolce", "above": True}, e["texts"])
        self.assertIn("very loud", [t["words"] for t in e["texts"]])
        self.assertEqual({(x["line"], x["syllable"]) for x in e["lyrics"]} >= {(1, "begin"), (1, "end"), (2, "single")},
                         True)
        self.assertEqual([c["pos"] for c in e["chords"]], ["0", "4", "8", "12", "16"])
        self.assertIn({"flow": 1, "player": "Flute", "pos": "0", "name": "mf"}, e["dynamics"])
        self.assertTrue(e["props"], "properties the finishing script sets")


if __name__ == "__main__":
    unittest.main()
