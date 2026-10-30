"""Write the texts fixture as MusicXML, and what the find and replace recipe should do to it.

    python fixtures/make_texts_xml.py   ->  fixtures/build/texts.musicxml, fixtures/texts.expected.json

One flow of 4/4 bars for flute and soprano. The flute has a staff text at the start of bars 1 to 4 and 6: "dolce",
"dolce e cantabile" (which finish_texts.lua puts below the staff by event id, for every layout), "Dolce",
"dolcemente" and "dolce assai" (which it colours, a setting of its own). finish_texts.lua also adds "dolce sempre" in
bar 5 and makes it a system text, and "dolce cantando" in bar 7, flipped below with Edit.FlipItem for the full score
only. The soprano sings "sweet", "dol-ce" and "dolce" on line 1, with "dolce" under the first note on line 2, and
there are chord symbols C, Am and G7 at the start of bars 1 to 3. "texts", "lyrics" and "chords" are what the fixture
holds afterwards; "rows" are the searches the tests run and what each should list and leave, worked out by hand.
"""
import json
import sys
from pathlib import Path
from xml.sax.saxutils import escape

sys.path.insert(0, str(Path(__file__).resolve().parent))
from make_sample_xml import parse_spelling  # noqa: E402

HERE = Path(__file__).resolve().parent
BUILD = HERE / "build"
BARS = 7
TEXTS = {1: "dolce", 2: "dolce e cantabile", 3: "Dolce", 4: "dolcemente", 6: "dolce assai"}
# Made with createText in finish_texts.lua: the import turned "dolce cantando" (and "poco dolce") into "dolce".
SYSTEM_TEXT = {"bar": 5, "words": "dolce sempre"}
FLIPPED_TEXT = {"bar": 7, "words": "dolce cantando"}
BELOW_BAR, COLOURED_BAR, COLOUR = 2, 6, "#ff0000c0"
CHORDS = {1: ("C", "major"), 2: ("A", "minor"), 3: ("G", "dominant")}
# soprano: {bar: [(spelling, [(line, text, syllabic)])]}, one quarter note each; other bars are whole-bar rests
LYRICS = {
    1: [("C5", [(1, "sweet", "single"), (2, "dolce", "single")]), ("D5", [(1, "dol", "begin")]),
        ("E5", [(1, "ce", "end")]), ("F5", [])],
    2: [("C5", [(1, "dolce", "single")]), ("D5", []), ("E5", []), ("F5", [])],
}


def _pitch_xml(s):
    step, alter, octave = parse_spelling(s)
    return (f"<pitch><step>{step}</step>" + (f"<alter>{alter}</alter>" if alter else "")
            + f"<octave>{octave}</octave></pitch>")


def _attributes(n):
    if n != 1:
        return ""
    return ("<attributes><divisions>1</divisions><key><fifths>0</fifths></key>"
            "<time><beats>4</beats><beat-type>4</beat-type></time><clef><sign>G</sign><line>2</line></clef>"
            "</attributes>")


def _flute_bar(n):
    out = [f'<measure number="{n}">', _attributes(n)]
    if n in CHORDS:
        root, kind = CHORDS[n]
        out.append(f"<harmony><root><root-step>{root}</root-step></root><kind>{kind}</kind></harmony>")
    if n in TEXTS:
        out.append(f'<direction placement="above"><direction-type><words>{escape(TEXTS[n])}</words>'
                   "</direction-type></direction>")
    for s in ("C5", "D5", "E5", "F5"):
        out.append(f"<note>{_pitch_xml(s)}<duration>1</duration><voice>1</voice><type>quarter</type></note>")
    out.append("</measure>")
    return "".join(out)


def _soprano_bar(n):
    out = [f'<measure number="{n}">', _attributes(n)]
    if n not in LYRICS:
        out.append('<note><rest measure="yes"/><duration>4</duration><voice>1</voice></note>')
    for spelling, lyrics in LYRICS.get(n, []):
        body = "".join(f'<lyric number="{line}"><syllabic>{syllabic}</syllabic><text>{escape(text)}</text></lyric>'
                       for line, text, syllabic in lyrics)
        out.append(f"<note>{_pitch_xml(spelling)}<duration>1</duration><voice>1</voice><type>quarter</type>"
                   f"{body}</note>")
    out.append("</measure>")
    return "".join(out)


def build_xml():
    parts = [("P1", "Flute", "wind.flutes.flute", _flute_bar), ("P2", "Soprano", "voice.soprano", _soprano_bar)]
    part_list = "".join(
        f'<score-part id="{pid}"><part-name>{name}</part-name><score-instrument id="{pid}-I1">'
        f"<instrument-name>{name}</instrument-name><instrument-sound>{sound}</instrument-sound></score-instrument>"
        "</score-part>" for pid, name, sound, _ in parts)
    body = "".join(f'<part id="{pid}">' + "".join(bar(n) for n in range(1, BARS + 1)) + "</part>"
                   for pid, _, _, bar in parts)
    return ('<?xml version="1.0" encoding="UTF-8"?>\n'
            '<!DOCTYPE score-partwise PUBLIC "-//Recordare//DTD MusicXML 3.1 Partwise//EN" '
            '"http://www.musicxml.org/dtds/partwise.dtd">\n'
            '<score-partwise version="3.1"><work><work-title>Texts</work-title></work>'
            f"<part-list>{part_list}</part-list>{body}</score-partwise>\n")


def texts():
    out = [{"player": "Flute", "bar": bar, "words": words, "above": bar != BELOW_BAR, "system": False}
           for bar, words in TEXTS.items()]
    out.append({"player": "Flute", "bar": FLIPPED_TEXT["bar"], "words": FLIPPED_TEXT["words"], "above": False,
                "system": False})
    out.append({"player": "-", "bar": SYSTEM_TEXT["bar"], "words": SYSTEM_TEXT["words"], "above": True,
                "system": True})
    return sorted(out, key=lambda t: t["bar"])


def lyrics():
    out = []
    for bar, notes in LYRICS.items():
        for beat, (_, items) in enumerate(notes, start=1):
            for line, text, syllabic in items:
                out.append({"bar": bar, "beat": beat, "line": line, "text": text, "syllable": syllabic})
    return out


def chords():
    names = {"major": "", "minor": "m", "dominant": "7"}
    return [{"bar": bar, "name": root + names[kind]} for bar, (root, kind) in CHORDS.items()]


def _line(kind, bar, who, words, beat=1):
    return f"{kind}\tflow 1\tbar {bar}, beat {beat}\t{who}\t{words}"


# Each row: the lines the recipe should print (before the summary), the summary, and what the texts, lyrics and chords
# should be afterwards (only the ones that change, by bar, with their new words). The answers each row gives are in
# tests/dorico/test_examples.py.
ROWS = {
    "find": {
        "lines": [
            _line("staff text", 1, "Flute", "dolce"), _line("lyric", 1, "Soprano", "dolce"),
            _line("staff text", 2, "Flute", "dolce e cantabile"), _line("lyric", 2, "Soprano", "dolce"),
            _line("staff text", 3, "Flute", "Dolce"), _line("staff text", 4, "Flute", "dolcemente"),
            _line("system text", 5, "-", "dolce sempre"), _line("staff text", 6, "Flute", "dolce assai"),
            _line("staff text", 7, "Flute", "dolce cantando")],
        "summary": "Found 9; the first is selected.",
    },
    "findSopranoFromBar2": {
        "lines": [_line("lyric", 2, "Soprano", "dolce")],
        "summary": "Found 1; the first is selected.",
    },
    "replace": {
        "lines": [
            _line("staff text", 1, "Flute", "dolce -> sweet"),
            _line("lyric", 1, "Soprano", "dolce: left as it is, only a whole-word lyric on line 1 can be replaced"),
            _line("staff text", 2, "Flute", "dolce e cantabile -> sweet e cantabile"),
            _line("lyric", 2, "Soprano", "dolce -> sweet"),
            _line("staff text", 3, "Flute", "Dolce -> sweet"),
            _line("system text", 5, "-", "dolce sempre -> sweet sempre"),
            _line("staff text", 6, "Flute",
                  "dolce assai: left as it is, it has settings of its own (kEventColour)"),
            _line("staff text", 7, "Flute",
                  "dolce cantando: left as it is, it is above or below the staff in one layout only")],
        "summary": "Replaced 5; left 3 as they were.",
        "texts": {1: "sweet", 2: "sweet e cantabile", 3: "sweet", 5: "sweet sempre"},
        "lyrics": {2: "sweet"},
    },
    "pattern": {
        "lines": [_line("system text", 5, "-", "dolce sempre -> sempre dolce")],
        "summary": "Replaced 1; left 0 as they were.",
        "texts": {5: "sempre dolce"},
    },
    "chord": {
        "lines": [_line("chord symbol", 2, "-", "Am -> Dm")],
        "summary": "Replaced 1; left 0 as they were.",
        "chords": {2: "Dm"},
    },
    "chordUnreadable": {
        "lines": [_line("chord symbol", 3, "-",
                        "G7: left as it is, Dorico couldn't read the new one, so the old one is still there")],
        "summary": "Replaced 0; left 1 as they were.",
    },
}


def expected():
    return {"texts": texts(), "lyrics": lyrics(), "chords": chords(), "belowBar": BELOW_BAR,
            "colouredBar": COLOURED_BAR, "colour": COLOUR, "flippedText": FLIPPED_TEXT, "systemText": SYSTEM_TEXT,
            "rows": ROWS}


def main():
    BUILD.mkdir(exist_ok=True)
    (BUILD / "texts.musicxml").write_text(build_xml(), encoding="utf-8")
    (HERE / "texts.expected.json").write_text(json.dumps(expected(), indent=1, ensure_ascii=False) + "\n",
                                              encoding="utf-8")


if __name__ == "__main__":
    main()
