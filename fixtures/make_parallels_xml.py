"""Write the parallels fixture as MusicXML, and what the parallel fifths recipe should find in it.

    python fixtures/make_parallels_xml.py   ->  fixtures/build/parallels.musicxml, fixtures/parallels.expected.json

One flow of 4/4 bars for flute, violin, viola, bassoon and cello. Each odd bar holds one case for two of them, and the
other players rest, with a bar of rests after it, so no case runs into the next. The findings were worked out by hand
from the notes, not by the recipe: consecutive fifths (a compound one), octaves, unisons, repeated notes (no motion),
two fifths with a rest between, crossed parts, a hidden fifth and contrary octaves between the outer parts, a doubling
of six notes in octaves, and two notes in octaves after it. "userColours" are the colours finish_parallels.lua gives
two notes, which the recipe must leave alone.
"""
import json
import sys
from pathlib import Path
from xml.sax.saxutils import escape

sys.path.insert(0, str(Path(__file__).resolve().parent))
from make_sample_xml import midi, parse_spelling  # noqa: E402

HERE = Path(__file__).resolve().parent
BUILD = HERE / "build"
DIVISIONS = 1
BARS = 20
PLAYERS = [
    {"name": "Flute", "sound": "wind.flutes.flute", "clef": ("G", 2)},
    {"name": "Violin", "sound": "strings.violin", "clef": ("G", 2)},
    {"name": "Viola", "sound": "strings.viola", "clef": ("C", 3)},
    {"name": "Bassoon", "sound": "wind.reed.bassoon", "clef": ("F", 4)},
    {"name": "Cello", "sound": "strings.cello", "clef": ("F", 4)},
]
# player: {bar: [spelling or None for a rest, one per quarter]}; a bar not listed is a whole-bar rest.
MUSIC = {
    "Flute": {1: ["D5", "E5"], 5: ["G4", "A4"], 7: ["C5", "C5"], 9: ["D5", None, "E5"], 13: ["D5", "G5"],
              15: ["C5", "D5"]},
    "Violin": {3: ["C5", "D5"], 5: ["G4", "A4"], 11: ["C4", "D4"]},
    "Viola": {3: ["C4", "D4"], 11: ["G4", "A4"]},
    "Bassoon": {1: ["G3", "A3"], 7: ["F3", "F3"], 9: ["G3", None, "A3"], 13: ["A2", "C3"], 15: ["C3", "D2"],
                17: ["C2", "D2", "E2", "F2"], 18: ["G2", "A2"], 20: ["E2", "F2"]},
    "Cello": {17: ["C3", "D3", "E3", "F3"], 18: ["G3", "A3"], 20: ["E3", "F3"]},
}
FINDINGS = {
    "default": [
        {"kind": "fifths", "pos": 1, "a": "Flute", "b": "Bassoon"},
        {"kind": "octaves", "pos": 9, "a": "Violin", "b": "Viola"},
        {"kind": "unisons", "pos": 17, "a": "Flute", "b": "Violin"},
        {"kind": "fifths", "pos": 41, "a": "Violin", "b": "Viola"},
        {"kind": "octaves", "pos": 77, "a": "Bassoon", "b": "Cello"},
    ],
    "hiddenAndContrary": [
        {"kind": "hidden fifths", "pos": 49, "a": "Flute", "b": "Bassoon"},
        {"kind": "contrary octaves", "pos": 57, "a": "Flute", "b": "Bassoon"},
    ],
    "doublings": [{"kind": "octaves", "pos": p, "a": "Bassoon", "b": "Cello"} for p in (65, 66, 67, 68, 69)],
}
USER_COLOURS = [
    {"player": "Flute", "pos": 1, "colour": "#ffff0000", "how": "byId"},
    {"player": "Bassoon", "pos": 24, "colour": "#ff00ff00", "how": "panel"},
]


def _pitch_xml(s):
    step, alter, octave = parse_spelling(s)
    return (f"<pitch><step>{step}</step>" + (f"<alter>{alter}</alter>" if alter else "")
            + f"<octave>{octave}</octave></pitch>")


def _bar_xml(n, player):
    sign, line = player["clef"]
    out = [f'<measure number="{n}">']
    if n == 1:
        out.append(f"<attributes><divisions>{DIVISIONS}</divisions><key><fifths>0</fifths></key>"
                   f"<time><beats>4</beats><beat-type>4</beat-type></time>"
                   f"<clef><sign>{sign}</sign><line>{line}</line></clef></attributes>")
    beats = MUSIC[player["name"]].get(n)
    if not beats:
        out.append(f'<note><rest measure="yes"/><duration>{4 * DIVISIONS}</duration><voice>1</voice></note>')
    else:
        beats = beats + [None] * (4 - len(beats))
        for b in beats:
            body = "<rest/>" if b is None else _pitch_xml(b)
            out.append(f"<note>{body}<duration>{DIVISIONS}</duration><voice>1</voice><type>quarter</type></note>")
    out.append("</measure>")
    return "".join(out)


def build_xml():
    part_list, parts = [], []
    for i, player in enumerate(PLAYERS, start=1):
        pid = f"P{i}"
        part_list.append(
            f'<score-part id="{pid}"><part-name>{escape(player["name"])}</part-name>'
            f'<score-instrument id="{pid}-I1"><instrument-name>{escape(player["name"])}</instrument-name>'
            f'<instrument-sound>{player["sound"]}</instrument-sound></score-instrument></score-part>')
        parts.append(f'<part id="{pid}">' + "".join(_bar_xml(n, player) for n in range(1, BARS + 1)) + "</part>")
    return ('<?xml version="1.0" encoding="UTF-8"?>\n'
            '<!DOCTYPE score-partwise PUBLIC "-//Recordare//DTD MusicXML 3.1 Partwise//EN" '
            '"http://www.musicxml.org/dtds/partwise.dtd">\n'
            '<score-partwise version="3.1"><work><work-title>Parallels</work-title></work>'
            f'<part-list>{"".join(part_list)}</part-list>{"".join(parts)}</score-partwise>\n')


def notes():
    """Every note as {player, pos, spelling, pitch}, positions in quarter notes from the start of the flow."""
    out = []
    for player in PLAYERS:
        for bar, beats in sorted(MUSIC[player["name"]].items()):
            for k, b in enumerate(beats):
                if b is not None:
                    out.append({"player": player["name"], "pos": 4 * (bar - 1) + k, "spelling": b, "pitch": midi(b)})
    return out


def expected():
    return {"players": [p["name"] for p in PLAYERS], "notes": notes(), "findings": FINDINGS,
            "userColours": USER_COLOURS, "mark": "#ffd81b60"}


def main():
    BUILD.mkdir(exist_ok=True)
    (BUILD / "parallels.musicxml").write_text(build_xml(), encoding="utf-8")
    (HERE / "parallels.expected.json").write_text(json.dumps(expected(), indent=1, ensure_ascii=False) + "\n",
                                                  encoding="utf-8")


if __name__ == "__main__":
    main()
