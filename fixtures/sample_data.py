"""The sample project's music, as data. fixtures/make_sample_xml.py writes it as MusicXML and as expected.json.

Each part has eight bars of 4/4. A bar is {voice: [item, ...]}, voices numbered as MusicXML numbers them (1 and 2
on the top staff, 5 on the bottom one). Spellings are written pitch; the trumpet sounds a major second lower.
"""

FLOW_TITLE = "Sample"
SECOND_FLOW_TITLE = "Second movement"
BEATS = 4


def N(spelling, quarters, **opts):
    """A note, or a chord when spelling is a list. opts: dynamic, slur ("start"/"stop"), tie ("start"/"stop"),
    lyric."""
    return {"kind": "note", "pitches": spelling if isinstance(spelling, list) else [spelling], "quarters": quarters,
            **opts}


def R(quarters):
    return {"kind": "rest", "quarters": quarters}


def G(spelling):
    """A grace note before the next note."""
    return {"kind": "grace", "pitches": [spelling]}


FLUTE = {
    "name": "Flute", "sound": "wind.flutes.flute", "staves": 1, "transpose": None,
    "bars": [
        {1: [N("C5", 1, dynamic="mf", slur="start"), N("D5", 1), N("E5", 1), N("F5", 1, slur="stop")]},
        {1: [N("G5", 2), N("A3", 2)]},  # A3: below the flute's range
        {1: [N("E5", 2), N("D5", 1), N("C5", 1, tie="start")]},
        {1: [N("C5", 2, tie="stop"), R(2)]},
        {1: [N("E5", 4, dynamic="p")]},
        {1: [N("F5", 4)]},
        {1: [N("G5", 2), N("G5", 2)]},
        {1: [N("C6", 4)]},
    ],
}

TRUMPET = {
    # Written in D major (a MusicXML part's key is its written key), so it sounds in C like the rest. The name has a
    # non-ASCII letter for the examples to read back; "Trumpet in B♭" would come in as "Trumpet♭ (B)".
    "name": "Trumpet Zoë", "sound": "brass.trumpet", "staves": 1, "transpose": (-1, -2), "key": 2,
    # Dorico adds the transposition to the player's name, and tostring(player) gives it with its own flat token
    "player": "Trumpet Zoë (B{@flat@})",
    "bars": [
        {1: [N("A4", 1), N("A4", 1), N("B4", 1), N("C#5", 1)]},
        {1: [N("D5", 2), N("E5", 2)]},
        {1: [N("F#5", 4)]},
        {1: [N("E5", 1), N("D5", 1), N("C#5", 1), N("D5", 1)]},
        {1: [N("A4", 2), R(2)]},
        {1: [N("F#4", 1), N("G4", 1), N("A4", 1), N("B4", 1)]},
        {1: [N("A4", 4)]},
        {1: [N("D5", 4)]},
    ],
}

VIOLIN = {
    # a name with a comma and an ampersand, which commands must escape
    "name": "Violin, solo & tutti", "sound": "strings.violin", "staves": 1, "transpose": None,
    "bars": [
        {1: [N("G4", 1, lyric="Sing"), N("A4", 1, lyric="a"), N("B4", 1, lyric="lit"), N("C5", 1, lyric="tle")]},
        {1: [G("F5"), N("E5", 2, lyric="song"), N("D5", 2, lyric="of")]},
        {1: [N("C5", 4, lyric="joy")]},
        {1: [N("B4", 1, lyric="and"), N("A4", 1, lyric="a"), N("G4", 1, lyric="hap"), N("A4", 1, lyric="py")]},
        {1: [N("B4", 4)]},
        {1: [N("C5", 4)]},
        {1: [N("D5", 1), N("E5", 1), N("F5", 1), N("G5", 1)]},
        {1: [N("E5", 4)]},
    ],
}

PIANO = {
    # Outer notes: the only parallel fifth runs from bar 5 (C3 to G4) to bar 6 (D3 to A4).
    "name": "Piano", "sound": "keyboard.piano", "staves": 2, "transpose": None,
    "bars": [
        {1: [N(["C4", "E4", "G4"], 4)], 5: [N("C3", 4)]},        # C
        {1: [N(["E4", "A4", "C5"], 4)], 5: [N("A2", 4)]},        # Am
        {1: [N(["F4", "A4", "C5"], 4)], 5: [N("F2", 4)]},        # F
        {1: [N(["B3", "D4", "F4"], 4)], 5: [N("G2", 4)]},        # G7
        {1: [N("G4", 4)], 5: [N("C3", 4)]},
        {1: [N("A4", 4)], 5: [N("D3", 4)]},
        {1: [N("E5", 2), N("E5", 2)], 2: [N("C5", 1), N("C5", 1), N("C5", 1), N("C5", 1)], 5: [N("C3", 4)]},
        {1: [N("C5", 4)], 5: [N("C3", 4)]},
    ],
}

PARTS = [FLUTE, TRUMPET, VIOLIN, PIANO]

# Made by fixtures/finish_sample.lua: a second flow, with four flute notes (sounding) in it.
SECOND_FLOW_FLUTE = ["C5", "D5", "E5", "F5"]

# What the recipes should find.
OUT_OF_RANGE = [{"player": "Flute", "spelling": "A3", "bar": 2, "beat": 3}]
PARALLEL_FIFTHS = [{"player": "Piano", "bar": 6, "beat": 1}]
CHORDS = [{"bar": 1, "name": "C"}, {"bar": 2, "name": "Am"}, {"bar": 3, "name": "F"}, {"bar": 4, "name": "G7"}]
