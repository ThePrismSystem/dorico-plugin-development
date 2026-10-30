"""Write the cautionary fixture as MusicXML, and what the cautionary accidentals recipe should find in it.

    python fixtures/make_cautionary_xml.py   ->  fixtures/build/cautionary.musicxml, fixtures/cautionary.expected.json

One flow of 4/4 bars for flute, violin and piano, in C major until bar 31 and E-flat major from there. Each case uses
a letter of its own, or comes after a note that puts its letter back to the plain note, so no case runs into the
next: an F sharp then an F two bars later, a C sharp then a C four bars later, a G sharp then a G five bars later, a D
sharp tied over two barlines then a D, an A sharp on the piano's upper staff then an A on its lower staff, a violin B
flat then a flute B, an E flat then an E in the next bar (Dorico's own rule) and again, a B before the key change and
a B flat after it, an A natural in E-flat then an A flat two bars later, and a G sharp then a G that already has round
brackets set by hand. The findings were worked out by hand from the notes, not by the recipe, for each set of options
the tests use. "userBracket" is the accidental finish_cautionary.lua sets on that last G through the Properties panel,
which the recipe must leave alone.
"""
import json
import sys
from pathlib import Path
from xml.sax.saxutils import escape

sys.path.insert(0, str(Path(__file__).resolve().parent))
from make_sample_xml import parse_spelling  # noqa: E402

HERE = Path(__file__).resolve().parent
BUILD = HERE / "build"
DIVISIONS = 1
BARS = 38
KEY_CHANGE = 31
PLAYERS = [
    {"name": "Flute", "sound": "wind.flutes.flute", "staves": 1},
    {"name": "Violin", "sound": "strings.violin", "staves": 1},
    {"name": "Piano", "sound": "keyboard.piano", "staves": 2},
]
# player: {bar: {staff: [beat]}}; a beat is a spelling (a quarter note), None (a quarter rest), or (spelling, quarters,
# ties) with ties a list of "start" and "stop". A bar or staff not listed is a whole-bar rest.
MUSIC = {
    "Flute": {1: {1: ["F#5"]}, 3: {1: ["F5"]}, 5: {1: ["C#5"]}, 9: {1: ["C5"]}, 11: {1: ["G#4"]}, 16: {1: ["G4"]},
              18: {1: [("D#5", 4, ["start"])]}, 19: {1: [("D#5", 4, ["stop", "start"])]},
              20: {1: [("D#5", 2, ["stop"]), "D5"]}, 26: {1: ["B4"]}, 28: {1: ["Eb5"]}, 29: {1: ["E5"]},
              30: {1: ["E5", "B4"]}, 32: {1: ["A4"]}, 33: {1: ["Bb4"]}, 34: {1: ["Ab4"]}, 36: {1: ["G#4"]},
              38: {1: ["G4"]}},
    "Violin": {25: {1: ["Bb4"]}},
    "Piano": {22: {1: ["A#4"]}, 23: {2: ["A3"]}},
}


def finding(player, bar, beat, spelling, after):
    return {"player": player, "bar": bar, "beat": beat, "spelling": spelling, "after": after}


F5 = finding("Flute", 3, 1, "F5", "F#5 in bar 1")
C5 = finding("Flute", 9, 1, "C5", "C#5 in bar 5")
G4 = finding("Flute", 16, 1, "G4", "G#4 in bar 11")
D5 = finding("Flute", 20, 3, "D5", "D#5 tied into the bar")
A3 = finding("Piano", 23, 1, "A3", "A#4 on the other staff in bar 22")
B4 = finding("Flute", 26, 1, "B4", "Violin's Bb4 in bar 25")
AB4 = finding("Flute", 34, 1, "Ab4", "A4 in bar 32")
# What each set of options finds, in time order; the options are the recipe's defaults (look back 4 bars, count bars
# of rest, the instrument's other staves, not other instruments) with the changes named.
FINDINGS = {
    "default": [F5, C5, D5, A3, AB4],
    "lookBack2": [F5, D5, A3, AB4],
    "noLimit": [F5, C5, G4, D5, A3, AB4],
    "restsDontCount": [F5, C5, G4, D5, A3, AB4],
    "noOtherStaves": [F5, C5, D5, AB4],
    "otherInstruments": [F5, C5, D5, A3, B4, AB4],
}
USER_BRACKET = {"player": "Flute", "pos": 4 * 37, "value": "kRoundBrackets"}


def _pitch_xml(s):
    step, alter, octave = parse_spelling(s)
    return (f"<pitch><step>{step}</step>" + (f"<alter>{alter}</alter>" if alter else "")
            + f"<octave>{octave}</octave></pitch>")


TYPES = {1: "quarter", 2: "half", 4: "whole"}


def _staff_xml(beats, voice, staff):
    tag = f"<staff>{staff}</staff>" if staff else ""
    if not beats:
        return (f'<note><rest measure="yes"/><duration>{4 * DIVISIONS}</duration><voice>{voice}</voice>{tag}</note>')
    out, used = [], 0
    for b in beats:
        if isinstance(b, tuple):
            spelling, quarters, ties = b
        else:
            spelling, quarters, ties = b, 1, []
        body = "<rest/>" if spelling is None else _pitch_xml(spelling)
        tie = "".join(f'<tie type="{t}"/>' for t in ties)
        tied = "".join(f'<tied type="{t}"/>' for t in ties)
        notations = f"<notations>{tied}</notations>" if tied else ""
        out.append(f"<note>{body}<duration>{quarters * DIVISIONS}</duration>{tie}<voice>{voice}</voice>"
                   f"<type>{TYPES[quarters]}</type>{tag}{notations}</note>")
        used += quarters
    for _ in range(4 - used):
        out.append(f"<note><rest/><duration>{DIVISIONS}</duration><voice>{voice}</voice><type>quarter</type>"
                   f"{tag}</note>")
    return "".join(out)


def _bar_xml(n, player):
    out = [f'<measure number="{n}">']
    attributes = []
    if n == 1:
        attributes.append(f"<divisions>{DIVISIONS}</divisions><key><fifths>0</fifths></key>"
                          "<time><beats>4</beats><beat-type>4</beat-type></time>")
        if player["staves"] > 1:
            attributes.append('<staves>2</staves><clef number="1"><sign>G</sign><line>2</line></clef>'
                              '<clef number="2"><sign>F</sign><line>4</line></clef>')
        else:
            attributes.append("<clef><sign>G</sign><line>2</line></clef>")
    if n == KEY_CHANGE:
        attributes.append("<key><fifths>-3</fifths></key>")
    if attributes:
        out.append("<attributes>" + "".join(attributes) + "</attributes>")
    bar = MUSIC[player["name"]].get(n, {})
    if player["staves"] == 1:
        out.append(_staff_xml(bar.get(1), 1, None))
    else:
        out.append(_staff_xml(bar.get(1), 1, 1))
        out.append(f"<backup><duration>{4 * DIVISIONS}</duration></backup>")
        out.append(_staff_xml(bar.get(2), 5, 2))
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
            '<score-partwise version="3.1"><work><work-title>Cautionary</work-title></work>'
            f'<part-list>{"".join(part_list)}</part-list>{"".join(parts)}</score-partwise>\n')


def notes():
    """Every note as {player, staff, pos, spelling, quarters}, a tied note once with its whole length."""
    out = []
    for player in PLAYERS:
        for bar, staves in sorted(MUSIC[player["name"]].items()):
            for staff, beats in sorted(staves.items()):
                pos = 4 * (bar - 1)
                for b in beats:
                    spelling, quarters, ties = b if isinstance(b, tuple) else (b, 1, [])
                    if spelling is not None and "stop" in ties:
                        out[-1]["quarters"] += quarters
                    elif spelling is not None:
                        out.append({"player": player["name"], "staff": staff, "pos": pos, "spelling": spelling,
                                    "quarters": quarters})
                    pos += quarters
    return out


def expected():
    return {"players": [p["name"] for p in PLAYERS], "notes": notes(), "keyChange": 4 * (KEY_CHANGE - 1),
            "findings": FINDINGS, "userBracket": USER_BRACKET}


def main():
    BUILD.mkdir(exist_ok=True)
    (BUILD / "cautionary.musicxml").write_text(build_xml(), encoding="utf-8")
    (HERE / "cautionary.expected.json").write_text(json.dumps(expected(), indent=1, ensure_ascii=False) + "\n",
                                                   encoding="utf-8")


if __name__ == "__main__":
    main()
