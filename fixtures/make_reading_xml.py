"""Write the reading fixture as MusicXML, and what reading it back should find.

    python fixtures/make_reading_xml.py   ->  fixtures/build/reading.musicxml, fixtures/reading.expected.json

The project holds one of each kind of item the reader reads: notes with articulations, a triplet, a grace note and a
tie, a key change and a time change, staff text, a tempo, a rehearsal mark, a hairpin and one of each common dynamic,
chord symbols, two lines of lyrics with a melisma, string and fret numbers, and pizz. and arco. Positions and
durations in reading.expected.json are exact fractions of a quarter note from the start of the flow, as strings
("13/3"), and spellings are sounding pitch. "props" lists the note properties finish_reading.lua sets after the
import, since MusicXML can't carry them.

Dorico's MusicXML import puts every text above the staff, whatever its placement says, and keeps only the last
<words> of a direction, so the texts here are single words above.
"""
import json
import os
import sys
from fractions import Fraction as F
from pathlib import Path
from xml.sax.saxutils import escape

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_sample_xml import midi, parse_spelling, spelling_of, STEPS, SEMITONES  # noqa: E402

HERE = Path(__file__).resolve().parent
BUILD = HERE / "build"
DIVISIONS = 12  # per quarter note, so a triplet eighth is a whole number
FLOW_TITLE = "Reading"
SECOND_FLOW_TITLE = "Second"
SECOND_FLOW_FLUTE = ["C5", "D5", "E5", "F5"]
KEYS = {1: 0, 5: 1}  # bar: concert fifths
TIMES = {1: 4, 7: 3}  # bar: quarter beats


def bar_length(n):
    return TIMES[max(b for b in TIMES if b <= n)]


def bar_start(n):
    return sum(bar_length(b) for b in range(1, n))


def N(spelling, quarters, **opts):
    """A note, or a chord when spelling is a list. opts: dynamic, tie, tuplet ("start"/"stop"), art (a list of
    articulation names), string and fret, lyrics ([(line, text, syllabic[, "extend"])])."""
    return {"kind": "note", "pitches": spelling if isinstance(spelling, list) else [spelling], "quarters": F(quarters),
            **opts}


def G(spelling):
    return {"kind": "grace", "pitches": [spelling]}


def D(kind, **opts):
    """A direction at the next note: words (text, placement), tempo, rehearsal, wedge, harmony."""
    return {"kind": kind, **opts}


FLUTE = {
    "name": "Flute", "sound": "wind.flutes.flute", "staves": 1,
    "bars": {
        1: {1: [D("tempo", text="Allegro", bpm=120), D("words", text="dolce", placement="above"),
                N("C5", 1, dynamic="mf", art=["staccato"]), N("D5", 1, art=["accent"]), N("E5", 1, art=["tenuto"]),
                N("F#5", 1)]},
        2: {1: [N("G5", F(1, 3), tuplet="start"), N("A5", F(1, 3)), N("B5", F(1, 3), tuplet="stop"), N("F5", 1),
                G("E5"), N("G5", 2)]},
        3: {1: [D("words", text="espress.", placement="above"), N("E5", 2), N("D5", 1), N("C5", 1, tie="start")]},
        4: {1: [D("wedge", type="crescendo"), N("C5", 2, tie="stop"), D("wedge", type="stop"),
                N("D5", 2, dynamic="f")]},
        5: {1: [D("rehearsal", text="A"), N("G5", 4)]},
        6: {1: [D("words", text="con fuoco", placement="above"), N("F#5", 2), N("E5", 2)]},
        7: {1: [N("D5", 3)]},
        8: {1: [N("G5", 3)]},
    },
}

CLARINET = {
    # written a major second above sounding, so the written key is two sharps more than the concert key
    # Dorico adds the transposition to the player's name, and tostring(player) gives it with its own flat token
    "name": "Clarinet", "player": "Clarinet (B{@flat@})", "sound": "wind.reed.clarinet.bflat", "staves": 1,
    "transpose": (-1, -2), "keyOffset": 2,
    "bars": {
        1: {1: [N("E5", 4, dynamic="pp")]},
        2: {1: [N("F#5", 2, dynamic="p"), N("G#5", 2)]},
        3: {1: [N("A5", 4, dynamic="mp")]},
        4: {1: [N("G5", 2, dynamic="mf"), N("F#5", 2)]},
        5: {1: [N("B5", 4, dynamic="f")]},
        6: {1: [N("C#6", 2, dynamic="ff"), N("B5", 2)]},
        7: {1: [N("A5", 3, dynamic="fp")]},
        8: {1: [N("E5", 3, dynamic="sfz")]},
    },
}

GUITAR = {
    # written an octave above sounding
    "name": "Guitar", "sound": "pluck.guitar.acoustic", "staves": 1, "transpose": (0, 0, -1), "octaveClef": True,
    "bars": {
        1: {1: [D("harmony", root="C", chord="major"), N("C4", 1, string=5, fret=3), N("E4", 1, string=4, fret=2),
                N("G4", 1, string=3, fret=0), N("C5", 1, string=2, fret=1)]},
        2: {1: [D("harmony", root="G", chord="dominant"), N("B3", 4)]},
        3: {1: [D("harmony", root="A", chord="minor"), N("A3", 4)]},
        4: {1: [D("harmony", root="F", chord="major"), N("A3", 4)]},
        5: {1: [D("harmony", root="G", chord="major"), N("B3", 4)]},
        6: {1: [N("A3", 4)]},
        7: {1: [N("B3", 3)]},
        8: {1: [N("G3", 3)]},
    },
}

PIANO = {
    "name": "Piano", "sound": "keyboard.piano", "staves": 2,
    "bars": {
        1: {1: [N(["E5", "G5"], 2), N(["F5", "A5"], 2)], 2: [N("C5", 4)], 5: [N("C3", 4)]},
        2: {1: [N("G5", 4)], 5: [N("G2", 4)]},
        3: {1: [N("E5", 4)], 5: [N("A2", 4)]},
        4: {1: [N("F5", 4)], 5: [N("F2", 4)]},
        5: {1: [N("G5", 4)], 5: [N("G2", 4)]},
        6: {1: [N("F#5", 4)], 5: [N("D3", 4)]},
        7: {1: [N("D5", 3)], 5: [N("G2", 3)]},
        8: {1: [N("G5", 3)], 5: [N("G2", 3)]},
    },
}

SOPRANO = {
    "name": "Soprano", "sound": "voice.soprano", "staves": 1,
    "bars": {
        1: {1: [N("C5", 1, lyrics=[(1, "Hal", "begin"), (2, "Glo", "begin")]),
                N("D5", 1, lyrics=[(1, "le", "middle"), (2, "ri", "middle")]),
                N("E5", 1, lyrics=[(1, "lu", "middle"), (2, "a", "end")]),
                N("F5", 1, lyrics=[(1, "jah", "end"), (2, "now", "single")])]},
        2: {1: [N("G5", 2, lyrics=[(1, "Sing", "single", "extend")]), N("A5", 2)]},
        3: {1: [N("G5", 4, lyrics=[(1, "joy", "single")])]},
        4: {1: [N("F5", 4)]},
        5: {1: [N("G5", 4)]},
        6: {1: [N("A5", 4)]},
        7: {1: [N("B5", 3)]},
        8: {1: [N("G5", 3)]},
    },
}

VIOLIN = {
    "name": "Violin", "sound": "strings.violin", "staves": 1,
    "bars": {
        1: {1: [D("words", text="pizz.", placement="above"), N("G4", 1), N("A4", 1), N("B4", 1), N("C5", 1)]},
        2: {1: [N("D5", 4)]},
        3: {1: [D("words", text="arco", placement="above"), N("E5", 4)]},
        4: {1: [N("F5", 4)]},
        5: {1: [N("G5", 4)]},
        6: {1: [N("F#5", 4)]},
        7: {1: [N("G5", 3)]},
        8: {1: [N("B4", 3)]},
    },
}

PARTS = [FLUTE, CLARINET, GUITAR, PIANO, SOPRANO, VIOLIN]
TECHNIQUES = {"pizz.", "arco"}

# Set by finish_reading.lua after the import. how: "lua" (the property table, so no context), "command" (the
# selection, through Dorico's own command), "byId" (EventEdit.ChangeProperty), "menu" (a menu command on the selection)
# and "part" (the Properties panel with the flute part on screen, which build_reading.py arranges).
PROPS = [
    {"player": "Flute", "pos": "0", "spelling": "C5", "property": "kNoteheadSetOverride",
     "value": "noteheadset.diamondNoteheads", "how": "lua"},
    {"player": "Flute", "pos": "1", "spelling": "D5", "property": "kNoteheadSetOverride",
     "value": "noteheadset.Xnoteheads", "how": "command"},
    {"player": "Flute", "pos": "2", "spelling": "E5", "property": "kEventColour", "value": "#ff00a050", "how": "part"},
    {"player": "Clarinet (B{@flat@})", "pos": "0", "spelling": "D5", "property": "kEventColour", "value": "#ff0080ff",
     "how": "byId"},
    {"player": "Piano", "pos": "0", "spelling": "C3", "property": "kEventColour", "value": "#ffc80000", "how": "lua"},
    {"player": "Violin", "pos": "0", "spelling": "G4", "property": "kNoteAccidentalVisibility_v3",
     "value": "kRoundBrackets", "how": "byId"},
    {"player": "Violin", "pos": "1", "spelling": "A4", "property": "kNoteAccidentalVisibility_v3",
     "value": "kSquareBrackets", "how": "menu"},
]


def player_name(part):
    return part.get("player", part["name"])


def transposed(s, interval):
    """Written to sounding: interval = (diatonic, chromatic[, octaves]) as MusicXML's <transpose> gives it."""
    if not interval:
        return s
    diatonic, chromatic = interval[0], interval[1]
    octaves = interval[2] if len(interval) > 2 else 0
    step, _, octave = parse_spelling(s)
    index = STEPS.index(step) + diatonic
    new_step, new_octave = STEPS[index % 7], octave + index // 7 + octaves
    natural = 12 * (new_octave + 1) + SEMITONES[new_step]
    return spelling_of(new_step, midi(s) + chromatic + 12 * octaves - natural, new_octave)


def note_type(q):
    return {F(1, 3): ("eighth", 0), F(1, 2): ("eighth", 0), F(1): ("quarter", 0), F(2): ("half", 0),
            F(3): ("half", 1), F(4): ("whole", 0)}[q]


def _pitch_xml(s):
    step, alter, octave = parse_spelling(s)
    return (f"<pitch><step>{step}</step>" + (f"<alter>{alter}</alter>" if alter else "")
            + f"<octave>{octave}</octave></pitch>")


def _direction_xml(item, staff):
    kind = item["kind"]
    if kind == "harmony":
        return f'<harmony><root><root-step>{item["root"]}</root-step></root><kind>{item["chord"]}</kind></harmony>'
    if kind == "words":
        body = f"<words>{escape(item['text'])}</words>"
        return f'<direction placement="{item["placement"]}"><direction-type>{body}</direction-type>{staff}</direction>'
    if kind == "tempo":
        return (f'<direction placement="above"><direction-type><words>{escape(item["text"])}</words></direction-type>'
                f'<direction-type><metronome><beat-unit>quarter</beat-unit><per-minute>{item["bpm"]}</per-minute>'
                f'</metronome></direction-type>{staff}<sound tempo="{item["bpm"]}"/></direction>')
    if kind == "rehearsal":
        return (f'<direction placement="above"><direction-type><rehearsal>{escape(item["text"])}</rehearsal>'
                f"</direction-type>{staff}</direction>")
    if kind == "wedge":
        return (f'<direction placement="below"><direction-type><wedge type="{item["type"]}"/></direction-type>'
                f"{staff}</direction>")
    raise ValueError(kind)


def _items_xml(items, voice, staves):
    out = []
    staff = f"<staff>{2 if voice >= 5 else 1}</staff>" if staves > 1 else ""
    for item in items:
        if item["kind"] == "grace":
            out.append(f'<note><grace slash="yes"/>{_pitch_xml(item["pitches"][0])}<voice>{voice}</voice>'
                       f"<type>eighth</type>{staff}</note>")
            continue
        if item["kind"] != "note":
            out.append(_direction_xml(item, staff))
            continue
        if item.get("dynamic"):
            out.append(f'<direction placement="below"><direction-type><dynamics><{item["dynamic"]}/></dynamics>'
                       f"</direction-type>{staff}</direction>")
        kind, dots = note_type(item["quarters"])
        triplet = item["quarters"] == F(1, 3)
        for i, pitch in enumerate(item["pitches"]):
            parts = ["<note>", "<chord/>" if i else "", _pitch_xml(pitch),
                     f"<duration>{int(item['quarters'] * DIVISIONS)}</duration>"]
            notations = []
            if item.get("tie"):
                parts.append(f'<tie type="{item["tie"]}"/>')
                notations.append(f'<tied type="{item["tie"]}"/>')
            if item.get("tuplet") and i == 0:
                notations.append(f'<tuplet type="{item["tuplet"]}"/>')
            if item.get("art") and i == 0:
                notations.append("<articulations>" + "".join(f"<{a}/>" for a in item["art"]) + "</articulations>")
            if "string" in item:
                notations.append(f'<technical><string>{item["string"]}</string><fret>{item["fret"]}</fret></technical>')
            parts += [f"<voice>{voice}</voice>", f"<type>{kind}</type>", "<dot/>" * dots]
            if triplet:
                parts.append("<time-modification><actual-notes>3</actual-notes><normal-notes>2</normal-notes>"
                             "</time-modification>")
            parts.append(staff)
            if notations:
                parts.append("<notations>" + "".join(notations) + "</notations>")
            if i == 0:
                for lyric in item.get("lyrics", []):
                    line, text, syllabic = lyric[:3]
                    extend = "<extend/>" if len(lyric) > 3 else ""
                    parts.append(f'<lyric number="{line}"><syllabic>{syllabic}</syllabic>'
                                 f"<text>{escape(text)}</text>{extend}</lyric>")
            parts.append("</note>")
            out.append("".join(parts))
    return "".join(out)


def _attributes(part, n):
    out = []
    if n == 1:
        out.append(f"<divisions>{DIVISIONS}</divisions>")
    if n in KEYS:
        out.append(f"<key><fifths>{KEYS[n] + part.get('keyOffset', 0)}</fifths></key>")
    if n in TIMES:
        out.append(f"<time><beats>{TIMES[n]}</beats><beat-type>4</beat-type></time>")
    if n == 1:
        if part["staves"] > 1:
            out.append('<staves>2</staves><clef number="1"><sign>G</sign><line>2</line></clef>'
                       '<clef number="2"><sign>F</sign><line>4</line></clef>')
        elif part.get("octaveClef"):
            out.append("<clef><sign>G</sign><line>2</line><clef-octave-change>-1</clef-octave-change></clef>")
        else:
            out.append("<clef><sign>G</sign><line>2</line></clef>")
        t = part.get("transpose")
        if t:
            octave = f"<octave-change>{t[2]}</octave-change>" if len(t) > 2 else ""
            out.append(f"<transpose><diatonic>{t[0]}</diatonic><chromatic>{t[1]}</chromatic>{octave}</transpose>")
    return "<attributes>" + "".join(out) + "</attributes>" if out else ""


def build_xml():
    part_list, parts = [], []
    for i, part in enumerate(PARTS, start=1):
        pid = f"P{i}"
        part_list.append(
            f'<score-part id="{pid}"><part-name>{escape(part["name"])}</part-name>'
            f'<score-instrument id="{pid}-I1"><instrument-name>{escape(part["name"])}</instrument-name>'
            f'<instrument-sound>{part["sound"]}</instrument-sound></score-instrument></score-part>')
        bars = []
        for n in sorted(part["bars"]):
            bar = part["bars"][n]
            out = [f'<measure number="{n}">', _attributes(part, n)]
            for k, voice in enumerate(sorted(bar)):
                if k:
                    out.append(f"<backup><duration>{bar_length(n) * DIVISIONS}</duration></backup>")
                out.append(_items_xml(bar[voice], voice, part["staves"]))
            out.append("</measure>")
            bars.append("".join(out))
        parts.append(f'<part id="{pid}">' + "".join(bars) + "</part>")
    return ('<?xml version="1.0" encoding="UTF-8"?>\n'
            '<!DOCTYPE score-partwise PUBLIC "-//Recordare//DTD MusicXML 3.1 Partwise//EN" '
            '"http://www.musicxml.org/dtds/partwise.dtd">\n'
            '<score-partwise version="3.1">'
            f"<work><work-title>{escape(FLOW_TITLE)}</work-title></work>"
            '<identification><creator type="composer">Reading Fixture</creator></identification>'
            f'<part-list>{"".join(part_list)}</part-list>{"".join(parts)}</score-partwise>\n')


def walk(part):
    """(position, item) for every item of a part, in order, with each direction at the position of the next note."""
    for n in sorted(part["bars"]):
        for voice, items in part["bars"][n].items():
            pos = F(bar_start(n))
            for item in items:
                yield pos, voice, item
                if item["kind"] == "note":
                    pos += item["quarters"]


def _notes(part):
    notes, open_ties = [], {}
    for pos, _, item in walk(part):
        if item["kind"] == "grace":
            notes.append({"spelling": transposed(item["pitches"][0], part.get("transpose")), "pos": str(pos),
                          "duration": None, "grace": True})
        elif item["kind"] == "note":
            for pitch in item["pitches"]:
                spelling = transposed(pitch, part.get("transpose"))
                if item.get("tie") == "stop":
                    joined = open_ties.pop(spelling)
                    joined["duration"] = str(F(joined["duration"]) + item["quarters"])
                    continue
                note = {"spelling": spelling, "pos": str(pos), "duration": str(item["quarters"]), "grace": False}
                if item.get("art"):
                    note["articulations"] = item["art"]
                if "string" in item:
                    note["string"], note["fret"] = item["string"], item["fret"]
                notes.append(note)
                if item.get("tie") == "start":
                    open_ties[spelling] = note
    notes.sort(key=lambda x: (F(x["pos"]), midi(x["spelling"])))
    return notes


def expected():
    texts, lyrics, chords, dynamics, techniques, tempos, rehearsals, tuplets, wedges = [], [], [], [], [], [], [], [], []
    for part in PARTS:
        name = player_name(part)
        for pos, _, item in walk(part):
            p = str(pos)
            kind = item["kind"]
            if kind == "words":
                words = item["text"]
                if words in TECHNIQUES:
                    techniques.append({"flow": 1, "player": name, "pos": p, "name": words})
                else:
                    texts.append({"flow": 1, "player": name, "pos": p, "words": words,
                                  "above": item["placement"] == "above"})
            elif kind == "harmony":
                chords.append({"flow": 1, "pos": p, "root": item["root"], "chord": item["chord"]})
            elif kind == "tempo":
                tempos.append({"flow": 1, "pos": p, "text": item["text"], "bpm": item["bpm"]})
            elif kind == "rehearsal":
                rehearsals.append({"flow": 1, "pos": p, "text": item["text"]})
            elif kind == "wedge":
                wedges.append({"flow": 1, "player": name, "pos": p, "type": item["type"]})
            elif kind == "note":
                if item.get("dynamic"):
                    dynamics.append({"flow": 1, "player": name, "pos": p, "name": item["dynamic"]})
                if item.get("tuplet") == "start":
                    tuplets.append({"flow": 1, "player": name, "pos": p, "actual": 3, "normal": 2})
                for lyric in item.get("lyrics", []):
                    lyrics.append({"flow": 1, "player": name, "pos": p, "line": lyric[0], "text": lyric[1],
                                   "syllable": lyric[2], "extend": len(lyric) > 3})
    first = {"title": FLOW_TITLE, "players": [{"name": player_name(p), "notes": _notes(p)} for p in PARTS]}
    second = {"title": SECOND_FLOW_TITLE, "players": [
        {"name": player_name(p), "notes": [{"spelling": s, "pos": str(i), "duration": "1", "grace": False}
                                           for i, s in enumerate(SECOND_FLOW_FLUTE)] if p is FLUTE else []}
        for p in PARTS]}
    return {"flows": [first, second],
            "keys": [{"flow": 1, "pos": str(bar_start(b)), "fifths": f} for b, f in sorted(KEYS.items())],
            "times": [{"flow": 1, "pos": str(bar_start(b)), "beats": t, "beatType": 4} for b, t in sorted(TIMES.items())],
            "texts": texts, "lyrics": lyrics, "chords": chords, "dynamics": dynamics, "techniques": techniques,
            "tempos": tempos, "rehearsalMarks": rehearsals, "tuplets": tuplets, "hairpins": wedges, "props": PROPS}


def main():
    BUILD.mkdir(exist_ok=True)
    (BUILD / "reading.musicxml").write_text(build_xml(), encoding="utf-8")
    (HERE / "reading.expected.json").write_text(json.dumps(expected(), indent=1, ensure_ascii=False) + "\n",
                                                encoding="utf-8")


if __name__ == "__main__":
    main()
