"""Write the sample project as MusicXML, and what reading it back should find.

    python fixtures/make_sample_xml.py   ->  fixtures/build/sample.musicxml, fixtures/expected.json

Positions and durations in expected.json are in quarter notes from the start of the flow, as stream:dump() gives
them, and spellings are sounding pitch. A tied pair is one note: Dorico keeps a tied note as one event.
"""
import json
import os
import sys
from pathlib import Path
from xml.sax.saxutils import escape

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sample_data  # noqa: E402

HERE = Path(__file__).resolve().parent
BUILD = HERE / "build"
DIVISIONS = 4  # per quarter note
TYPES = {1: ("quarter", 0), 2: ("half", 0), 3: ("half", 1), 4: ("whole", 0)}
STEPS = "CDEFGAB"
SEMITONES = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def parse_spelling(s):
    """'Ab4' -> ('A', -1, 4); 'F#3' -> ('F', 1, 3)."""
    step, rest = s[0], s[1:]
    alter = 0
    while rest and rest[0] in "#b":
        alter += 1 if rest[0] == "#" else -1
        rest = rest[1:]
    return step, alter, int(rest)


def midi(s):
    step, alter, octave = parse_spelling(s)
    return 12 * (octave + 1) + SEMITONES[step] + alter


def spelling_of(step, alter, octave):
    return step + ("#" * alter if alter > 0 else "b" * -alter) + str(octave)


def transposed(s, interval):
    """Written to sounding for a part with MusicXML <transpose>: interval = (diatonic, chromatic) steps."""
    if not interval:
        return s
    diatonic, chromatic = interval
    step, _, octave = parse_spelling(s)
    index = STEPS.index(step) + diatonic
    new_step, new_octave = STEPS[index % 7], octave + index // 7
    natural = 12 * (new_octave + 1) + SEMITONES[new_step]
    return spelling_of(new_step, midi(s) + chromatic - natural, new_octave)


def _pitch_xml(s):
    step, alter, octave = parse_spelling(s)
    return (f"<pitch><step>{step}</step>" + (f"<alter>{alter}</alter>" if alter else "")
            + f"<octave>{octave}</octave></pitch>")


def _staff_of(voice):
    return 2 if voice >= 5 else 1


def _items_xml(items, voice, staves):
    out = []
    staff = f"<staff>{_staff_of(voice)}</staff>" if staves > 1 else ""
    for item in items:
        if item["kind"] == "rest":
            kind, dots = TYPES[item["quarters"]]
            out.append(f"<note><rest/><duration>{item['quarters'] * DIVISIONS}</duration><voice>{voice}</voice>"
                       f"<type>{kind}</type>{'<dot/>' * dots}{staff}</note>")
            continue
        if item["kind"] == "grace":
            out.append(f'<note><grace slash="yes"/>{_pitch_xml(item["pitches"][0])}<voice>{voice}</voice>'
                       f"<type>eighth</type>{staff}</note>")
            continue
        if item.get("dynamic"):
            out.append(f'<direction placement="below"><direction-type><dynamics><{item["dynamic"]}/></dynamics>'
                       f"</direction-type>{staff}</direction>")
        kind, dots = TYPES[item["quarters"]]
        for i, pitch in enumerate(item["pitches"]):
            parts = ["<note>", "<chord/>" if i else "", _pitch_xml(pitch),
                     f"<duration>{item['quarters'] * DIVISIONS}</duration>"]
            notations = []
            if item.get("tie"):
                parts.append(f'<tie type="{item["tie"]}"/>')
                notations.append(f'<tied type="{item["tie"]}"/>')
            if item.get("slur") and i == 0:
                notations.append(f'<slur type="{item["slur"]}" number="1"/>')
            parts += [f"<voice>{voice}</voice>", f"<type>{kind}</type>", "<dot/>" * dots, staff]
            if notations:
                parts.append("<notations>" + "".join(notations) + "</notations>")
            if item.get("lyric") and i == 0:
                parts.append(f'<lyric number="1"><syllabic>single</syllabic><text>{escape(item["lyric"])}</text></lyric>')
            parts.append("</note>")
            out.append("".join(parts))
    return "".join(out)


def _attributes(part):
    clefs = ('<clef number="1"><sign>G</sign><line>2</line></clef><clef number="2"><sign>F</sign><line>4</line></clef>'
             if part["staves"] > 1 else "<clef><sign>G</sign><line>2</line></clef>")
    transpose = ""
    if part["transpose"]:
        transpose = (f"<transpose><diatonic>{part['transpose'][0]}</diatonic>"
                     f"<chromatic>{part['transpose'][1]}</chromatic></transpose>")
    staves = f"<staves>{part['staves']}</staves>" if part["staves"] > 1 else ""
    return (f"<attributes><divisions>{DIVISIONS}</divisions><key><fifths>{part.get('key', 0)}</fifths></key>"
            f"<time><beats>{sample_data.BEATS}</beats><beat-type>4</beat-type></time>{staves}{clefs}{transpose}"
            "</attributes>")


def build_xml():
    part_list, parts = [], []
    for i, part in enumerate(sample_data.PARTS, start=1):
        pid = f"P{i}"
        part_list.append(
            f'<score-part id="{pid}"><part-name>{escape(part["name"])}</part-name>'
            f'<score-instrument id="{pid}-I1"><instrument-name>{escape(part["name"])}</instrument-name>'
            f'<instrument-sound>{part["sound"]}</instrument-sound></score-instrument></score-part>')
        bars = []
        for n, bar in enumerate(part["bars"], start=1):
            out = [f'<measure number="{n}">', _attributes(part) if n == 1 else ""]
            for k, voice in enumerate(sorted(bar)):
                if k:
                    out.append(f"<backup><duration>{sample_data.BEATS * DIVISIONS}</duration></backup>")
                out.append(_items_xml(bar[voice], voice, part["staves"]))
            out.append("</measure>")
            bars.append("".join(out))
        parts.append(f'<part id="{pid}">' + "".join(bars) + "</part>")
    return ('<?xml version="1.0" encoding="UTF-8"?>\n'
            '<!DOCTYPE score-partwise PUBLIC "-//Recordare//DTD MusicXML 3.1 Partwise//EN" '
            '"http://www.musicxml.org/dtds/partwise.dtd">\n'
            '<score-partwise version="3.1">'
            f'<work><work-title>{escape(sample_data.FLOW_TITLE)}</work-title></work>'
            '<identification><creator type="composer">Sample Generator</creator></identification>'
            f'<part-list>{"".join(part_list)}</part-list>{"".join(parts)}</score-partwise>\n')


def _notes(part):
    """Every note of a part, sounding, with ties joined."""
    notes = []
    for n, bar in enumerate(part["bars"]):
        for voice, items in bar.items():
            pos = n * sample_data.BEATS
            for item in items:
                if item["kind"] == "rest":
                    pos += item["quarters"]
                    continue
                if item["kind"] == "grace":
                    notes.append({"spelling": transposed(item["pitches"][0], part["transpose"]), "pos": pos,
                                  "duration": None, "grace": True})
                    continue
                for pitch in item["pitches"]:
                    spelling = transposed(pitch, part["transpose"])
                    if item.get("tie") == "stop":
                        joined = [x for x in notes if x["spelling"] == spelling and not x["grace"]
                                  and x["pos"] + x["duration"] == pos]
                        joined[-1]["duration"] += item["quarters"]
                    else:
                        notes.append({"spelling": spelling, "pos": pos, "duration": item["quarters"], "grace": False})
                pos += item["quarters"]
    notes.sort(key=lambda x: (x["pos"], midi(x["spelling"])))
    return notes


def expected():
    first = {"title": sample_data.FLOW_TITLE,
             "players": [{"name": p.get("player", p["name"]), "notes": _notes(p)} for p in sample_data.PARTS]}
    second = {"title": sample_data.SECOND_FLOW_TITLE, "players": [
        {"name": p.get("player", p["name"]), "notes": [{"spelling": s, "pos": i, "duration": 1, "grace": False}
                                      for i, s in enumerate(sample_data.SECOND_FLOW_FLUTE)]
         if p is sample_data.FLUTE else []} for p in sample_data.PARTS]}
    return {"flows": [first, second], "outOfRange": sample_data.OUT_OF_RANGE,
            "parallelFifths": sample_data.PARALLEL_FIFTHS, "chords": sample_data.CHORDS}


def main():
    BUILD.mkdir(exist_ok=True)
    (BUILD / "sample.musicxml").write_text(build_xml(), encoding="utf-8")
    (HERE / "expected.json").write_text(json.dumps(expected(), indent=1, ensure_ascii=False) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
