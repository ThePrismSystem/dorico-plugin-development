# The .dorico file format

A Dorico project file holds the whole score as a tree, and a Lua script can read it. Steinberg doesn't document the
format. Everything below was worked out by decoding saved projects, and each fact says how it is known. The reader
library in [`lib/scorereader`](../lib/scorereader) implements it.

The evidence is 52 projects: the fixtures in [`fixtures/`](../fixtures), copies of the 7 example projects Dorico 6
installs, and the 39 projects published at <https://ancientgroove.co.uk/dorico/index.html>. Together they were saved
by Dorico 6.0.22, 6.1.0, 6.1.5, 6.1.10, 6.2.0, 6.2.20 and 6.2.30. The probes are in [`spikes/`](../spikes), and
[`spikes.md`](spikes.md) records what each one found.

## The container

A `.dorico` file is a zip archive (deflate). A project saved by Dorico 6.2.30 holds:

| Entry | What it is |
| ----- | ---------- |
| `score.dtn` | The score, as a binary tree. Everything this document describes is in here. |
| `scorelibrary.dtn` | The project's library (styles, definitions), also a binary tree. |
| `META-INF/container.xml` | A short manifest. |
| `supplementary_data/scoreinfo/scoreinfo.xml` | The project info (title, composer, the Dorico versions that created and last saved it) as plain XML. |
| `supplementary_data/proofing/`, `workspace/`, `preview/`, `vstaudioengine/` and others | Proofreading filters, window layout, a preview PDF and PNG, and playback data. |

The example projects Dorico installs hold `score.xml` and `scorelibrary.xml` instead of the two `.dtn` files. Every
project the probes found anywhere else is binary, including the guided tutorials in Dorico's program folder, and no
setting or command for saving XML turned up (spike F7). Dorico 6.2.30 opens the XML projects.

## The two encodings

Both encodings hold the same tree. Each node has a name, a value (a string, often empty) and children.

### Binary: `score.dtn`

The numbers in the header are little-endian 32-bit integers; the ones after each record's tag byte are LEB128
varints.

```
u32 4, u32 1
u32 nameCount, then nameCount NUL-terminated node names
u32 valueCount, then valueCount NUL-terminated values (value 0 is "")
u32 nodeCount, then one record per node, node 0 the root:
  tag byte, name index, value index
  when the tag's 2 bit is set: child count, then that many child node ids
```

The tag's 1 bit marks a node whose children are a list. Each distinct value is stored once and shared. Stock Lua
decodes a 2.5 MB `score.dtn` in about 0.1 s, and every binary file from 6.0.22 to 6.2.30 starts with the same `4, 1`
header.

### XML: `score.xml`

Element names are node names and an element's text is its value. `array="true"` marks a list
node. The only attribute is `array`, and elements that hold other elements hold no text. Node ids follow document
order, parents first, as in the binary encoding.

## Versions

The root's first child is `fileVersion`, and `info` holds `createdVersion` and `lastSavedVersion`. Each Dorico release
wrote a different `fileVersion`:

| Last saved by | `fileVersion` | Encoding |
| ------------- | ------------- | -------- |
| 6.0.22 | 1.1392 | binary |
| 6.1.0 | 1.1416 | binary |
| 6.1.5 (the installed examples) | 1.1412 | XML |
| 6.1.10 | 1.1417 | binary |
| 6.2.0 | 1.1444 | binary |
| 6.2.20 | 1.1450 | binary |
| 6.2.30 | 1.1452 | binary |

The installed examples are out of order (1.1412 is lower than 6.1.0's 1.1416), which suggests an internal build saved
them.

Across these versions, the parts of the tree that hold the music didn't change: events, element tables, players,
layouts and project info have the same paths and value forms in every file. Each release only added options (about
80 new engraving, playback and notation options, such as `repeatNotationOptions` in 6.2.0) and a few library fields.
Nothing was renamed or removed. `spikes/f1_changes.lua` finds paths that every parent node has in some versions and
none has in others; outside options and the library, it found none.

So the reader treats `fileVersion` as a label. It checks the structure it relies on, reads any file whose structure
fits, and refuses one that doesn't, naming what didn't match.

## The tree

```
kScore
  fileVersion          "1.1452"
  idGenerators         the next free id of each kind (event, block, blockInstance, stave, ...)
  info                 title, subtitle, composer, lyricist, ..., createdVersion, lastSavedVersion, filePath
  scoreOptions         engravingOptions, noteInputOptions, playbackOptions, defaultNotationOptionsForFlow,
                       defaultLayoutOptionsMap, viewOptions
  library              the definitions the score uses: accidentals, noteheads and notehead sets, clefs,
                       paragraph and character styles, playing techniques, chord symbol appearances, fretted
                       instrument data, line styles, and more
  scorePlayers         array of scorePlayer
  scorePlayerGroups
  flows                array of flow
  textFlows
  layouts              array of layout
  playModeData         mixer, playback template and instrument playback data
```

### Players and instruments

A `scorePlayer` has a `playerID`, `displayName` and `displayShortName` (the names Dorico shows; `displayName` is what
`tostring(player)` gives, `{@flat@}` tokens included), `baseName`, `soloPlayer`, and `instruments`, a list of
`instrument` nodes. Lua gives players no ids, so the `playerID` is the file's own.

An `instrument` has an `instrumentID` (the id Lua gives the same instrument), an `entityID` naming its definition
(`instrument.wind.clarinet.bflat`), `numStaves`, the playing ranges `standardRange` and `advancedRange` (`D3-F6`),
its names, and for fretted instruments a `frettedInstrumentDataEntityID` and the tuning. The transposition is in the
definition: `library/instruments` holds one definition per instrument the project uses, and its
`pitchedInstrumentData` has `transposedDiatonicTransposition` and `transposedChromaticTransposition` (1 and 2 for a
B-flat clarinet: written a major second above sounding) and `concertOctaveTransposition`.

### Flows

A `flow` has:

- `flowID`, `flowName`, and `flowInfo` (the flow's own title, composer and so on).
- `flowPlayers`: one `flowPlayer` per player in the flow, with its `playerID` and `eventStreamID`, and per instrument a
  `flowPlayerInstrument` holding the `instrumentID` and the streams that belong to it: `voiceStreamInfos`
  (`voiceStreamID`, `defaultLogicalStaveID`, `voiceDirection`) and `staveStreamInfos` (`staveStreamID`, `staveID`,
  `nthStaveInInstrument`).
- `eventStreams`: one `eventStream` per stream, with its `streamID`, `eventStreamType` (such as
  `kGlobalTimebaseStream`) and `blockInstanceIDs`.
- `blocks`: each `block` has a `blockID`, a `parentEventStreamType` and the `events` it holds.
- `blockInstances`: each `blockInstance` places a block in a stream, with `blockInstanceID`, `blockID`, `streamID`
  and `position`.
- `elementTables`: the shared data some events point to (below).
- `notationOptions`: the flow's notation options, the same set as Notation Options in Dorico. For example,
  `accidentalStateCalcOptions` holds the accidental duration rule (`durationBehaviour`, such as `kCommonPractice`)
  and every cautionary-accidental setting (`showCautionariesForNotesInNextBarAtSameOctave = kParenthesise` and so
  on). Every flow carries a full set; `scoreOptions/defaultNotationOptionsForFlow` holds the defaults new flows take.
  Layout options are in each layout's `layoutOptions`, with defaults in `scoreOptions/defaultLayoutOptionsMap`.
  The reader gives each flow's accidental options as `flow.options.accidentals`: `durationBehaviour`, plus the
  `cautionaryOptions` and `commonOptions` groups under their own names. Values are Dorico's own (`kShow`, `kHide`,
  `kParenthesise`), with `true` and `false` turned into booleans. Every fixture so far uses `kCommonPractice`.

### Streams and what they hold

A stream's `streamID` is the id Lua gives the same stream (`flow.allStreams`, `voiceStreams`, `staveStreams` and
the rest), and its `eventStreamType` matches what `tostring(stream)` says. To find a stream's events, follow its
block instances to their blocks. In the reading fixture and in a 6.2.20 project with 8,794 notes, every event
`stream:dump()` listed was in those blocks with the same id and position, and none was missing.

| Stream | `eventStreamType` | Holds |
| ------ | ----------------- | ----- |
| one per flow | `kGlobalTimebaseStream` | time signatures, key signatures, tempos, chord symbols, rehearsal marks |
| one per staff | `kInstrumentStaveStream` | clefs, dynamics, and text imported from MusicXML |
| one per voice | `kVoiceStream` | notes, grace notes, rests, tuplets, slurs, lyrics, playing techniques, and text made with `createText` |
| one per player | `kPlayerStream` | events that belong to the whole player |

A flow's `flowPlayers` says who owns what. Each `flowPlayer` names its `playerID` and its player stream
(`eventStreamID`), and each of its `flowPlayerInstruments` names the `instrumentID` with its stave streams
(`staveStreamInfos`: `staveStreamID`, `staveID`, `nthStaveInInstrument`) and voice streams (`voiceStreamInfos`:
`voiceStreamID`, `instrumentID`, and `defaultLogicalStaveID`, the `staveID` of the stave the voice is on, which the
reader gives as the voice's `staff`). That's the same ownership Lua gives through `flow.instruments[i]`, which owns
`flow.voiceStreams[i]`.

### Events

Every event definition has `eventID`, `position`, `secondaryPosition`, `duration`, `secondaryEndOffset` and a
`propertyTable`. Positions and durations are in quarter notes, written as integers or exact fractions (`13/2`).

The probes found 46 kinds. These are the ones a plug-in is most likely to read, with the fields they add:

| Definition | Extra fields |
| ---------- | ------------ |
| `NoteEventDefinition` | `pitch` (sounding MIDI number), `logicalStaveIDOverride` |
| `GraceNoteEventDefinition` | `pitch`, `notatedDuration`, `slashed`, `logicalStaveIDOverride` |
| `RestEventDefinition` | `logicalStaveIDOverride` |
| `BarRestEventDefinition` | none |
| `TupletEventDefinition` | `tupletDefinition` |
| `SlurEventDefinition` | `slurElementID` |
| `LyricEventDefinition` | `lyricElementID` |
| `DynamicGroupEventDefinition` | `dynamicGroupID` |
| `TextEventDefinition` | `aboveOrBelow`, `isSystemText`, `alignWithSystemStart`, `content` |
| `ChordSymbolEventDefinition` | `rowIndex`, `chordSymbolData`, `chordDiagramData` |
| `BarDivisionEventDefinition` | `barDivisionElementID` (a time signature, or a barline or bar number change) |
| `TonalityDivisionEventDefinition` | `tonalityDivisionElementID` (a key signature) |
| `ClefEventDefinition` | `entityIDs`, `forceAfterGraceNotes` |
| `PlayingTechniqueEventDefinition` | `appearanceEntityID`, `appearanceType`, `data` |
| `ImmediateTempoChangeEventDefinition`, `GradualTempoChangeEventDefinition` | `data` |
| `RehearsalMarkEventDefinition` | `data` |
| `CommentEventDefinition` | `author`, `authorInitials`, `commentText`, `timestamp` |
| `OrnamentEventDefinition`, `OttavaLineEventDefinition` | `entityID` |
| `ArpeggioEventDefinition` | `arpeggioType`, `startVoiceID`, `endVoiceID` |
| `BreakEventDefinition` | `breakType`, `layoutIDWithFrameChainID`, `hideEmptyStaveOverrides` |

The rest are `AutomationEventDefinition`, `FiguredBassEventDefinition`, `TrillEventDefinition`,
`CondensationLabelEventDefinition`, `CondensingChangeEventDefinition`, `CueEventDefinition`,
`NoteSpacingChangeEventDefinition`, `PauseEventDefinition`, `PedalLineEventDefinition`,
`HarpPedalEventDefinition`, `HorizontalLineEventDefinition`, `GenerativeBarRepeatEventDefinition`,
`DivisiEventDefinition`, `BracketAndBarlineChangeEventDefinition`, `RepeatMarkerEventDefinition`,
`GlissandoLineEventDefinition`, `StaveCountChangeEventDefinition`, `RepeatEndingLineEventDefinition`,
`PercussionLegendEventDefinition`, `MIDITriggerEventDefinition`, `InstrumentChangeEventDefinition`,
`VerticalLineEventDefinition`, `GenerativeSlashEventDefinition`, `CutawayEventDefinition` and
`MultiRestEventDefinition`. None of the 52 projects has a chord symbol; the reading fixture has five.

### Reading common items

These come from the reading fixture (`fixtures/6.2.30/reading.dorico`), whose source says what each item is.

#### Text

A text event's words are in `content/paragraphs/paragraph`, which has a `paragraphStyleID`
(`paragraph.defaulttext`) and `fragments`. Each `fragment` has its words in `content` and its formatting in
`textFragmentStyle`. `aboveOrBelow` is `kAbove` or `kBelow`, and `isSystemText` says whether it's system text. A text flipped in
Dorico keeps its `aboveOrBelow` and gains a `kTextEventAboveOrBelow` property for the layout it was flipped in.

#### Chord symbols

`chordSymbolData/primaryChord` has a `root` (`noteName` `G`, `accidentalType` `kNatural`) and a
`definition` with a `quality` (`kMajor`, `kMinor`), an `interval` (`kNone`, `k7`) and `alterations`. The dump names
the same chords `C`, `G7`, `Am`, `F` and `G`. The reader names only these shapes, major, minor and the dominant seventh
(`kMajor` with `k7`), and only when nothing else is set: no alterations, custom name or custom intervals, no played
pitches, and no node it hasn't seen. Any other chord keeps its root, quality and interval but has no name.

#### Dynamics

A `DynamicGroupEventDefinition` points by `dynamicGroupID` to a `DynamicGroupElementDefinition`, whose
`subElements` are the dynamics in the group, each with a `position` from the group's start:

| Dynamic | Stored as |
| ------- | --------- |
| pp | `ImmediateChangeDynamicDefinition`, `intensity = steamVariantList:list: {int: 1}, {}, {bool: false}, {int: 2}` |
| p | `intensity = ... {int: 1}, {}, {bool: false}, {int: 1}` |
| mp | `intensity = ... {int: 1}, {}, {bool: true}, {}` |
| mf | `intensity = ... {int: 0}, {}, {bool: true}, {}` |
| f | `intensity = ... {int: 0}, {}, {bool: false}, {int: 1}` |
| ff | `intensity = ... {int: 0}, {}, {bool: false}, {int: 2}` |
| fp | `CombinedDynamicDefinition`, `direction = kDown`, `startIntensity = 1`, `endIntensity = 1` |
| sfz | `ForceDynamicDefinition`, `type = kForceDynamicSfz`, `intensityLevel = 1` |
| crescendo hairpin | `GradualChangeDynamicDefinition`, `direction = kGradualDynamicUp`, `duration = 2` |

So an immediate dynamic's intensity is: the family (0 forte, 1 piano), an empty item, whether it is mezzo, and how
many letters. The `intensityModifier` beside it was empty for all of these.

#### Lyrics

A `LyricEventDefinition` in a voice stream points by `lyricElementID` to a `LyricElementDefinition` with
the `text`, a `syllableType` (`kStart`, `kMiddle`, `kEnd`, `kWholeWord`), a `lineNumber` counted from 0, and
`lineType` (`kVerse`). A melisma is the lyric event's `duration`: a word held over two half notes lasts 4.

#### Time and key signatures

A `BarDivisionEventDefinition` in the timebase stream points by `barDivisionElementID` to
`barDivisionData/timeSignature/timeSignaturesAndDivisions/timeSignatureAndDivision/timeSignature`, with `numerator`,
`denominator` and the beat grouping. A pickup is `barDivisionData/irregularBarLength`, the first bar's length in quarter
notes: `1` for the one-beat pickup in 4/4 of `fixtures/6.2.30/pickup.dorico`, an import of `fixtures/pickup.musicxml`.
The reader gives it as the time signature's `pickup`. A `TonalityDivisionEventDefinition` points to
`tonalityDivisionData/keySignature`, whose `root` has a `tonalityType` (`kKeySigMajor`) and a `root` note (`noteName`
`G`, `accidentalID` `accidental.12et.western.natural`).

#### Tuplets, tempos and techniques

A tuplet's `tupletDefinition` is `steamVariantList:list: {int: 3}, {int: 2},
{list: {int: 7}, {int: 0}}, {bool: true}` for a triplet of eighths, and its `duration` is the span. A tempo's `data`
has the `text` (`Allegro`), `presetID` and `absoluteTempo/tempoValue` in microseconds per beat (500000 for 120 beats a
minute). A playing technique's `appearanceEntityID` (`pta.pizzText`) names its definition in the library.

### Element tables

Some events point into a table of elements in the flow's `elementTables`, and each element lists the events that
use it in `referencingEventIDs`:

| Table | Element | What it holds |
| ----- | ------- | ------------- |
| `BarDivisionElementTableDefinition` | `BarDivisionElementDefinition` | `barDivisionData`: the time signature (`timeSignature/timeSignaturesAndDivisions`), a barline change, a bar number change, an irregular bar length |
| `TonalityDivisionElementTableDefinition` | `TonalityDivisionElementDefinition` | `tonalityDivisionData`: the key signature (`keySignature/root` with `noteName`, `accidentalID` and `tonalityType` such as `kKeySigMajor`, and its `accidentals`) |
| `LyricElementTableDefinition` | `LyricElementDefinition` | `text`, `syllableType` (`kStart` and so on), `lineNumber`, `lineType` (`kVerse`), `lineLocation` (`kBelow`), and `richText` in the same form as a text event's `content` |
| `SlurElementTableDefinition` | `SlurElementDefinition` | the slur's properties |
| `DynamicGroupElementTableDefinition` | `DynamicGroupElementDefinition` | `subElements`: each dynamic in the group, such as a `ForceDynamicDefinition` with its `intensityLevel` or a `CombinedDynamicDefinition` |

An event's element id (`lyricElementID` and the like) matches the element's `elementID`.

### Layouts

A `layout` has `layoutID`, `layoutName`, `layoutNumber`, `layoutType` (`kFullScoreLayout` and others), `flowIDs`,
`layoutPlayers` and `layoutOptions`.

## Values

A node's value is one of these forms:

| Form | Example | Where |
| ---- | ------- | ----- |
| empty | `""` | most nodes that hold others |
| integer | `1586` | ids, counts, MIDI pitches |
| fraction | `13/2` | positions and durations |
| decimal | `0.000000` | intensities and other measurements |
| bool | `true`, `false` | flags |
| enum | `kCommonPractice` | choices |
| text | `Sample` | names, words, ids such as `paragraph.lyrics` |
| typed | `string: "C"`, `int: 4`, `double: 0.2`, `bool: true`, `null: `, `list: ...`, `steamVariantList:list: {int: -1}, {int: -1}, {bool: false}` | property values and contexts |

## Properties and contexts

An event's `propertyTable/entries` holds one `entry` per property that was set, with a `propertyType`
(`kNoteSpelling`, `kEventColour` and so on), a typed `value` (`string: "noteheadset.rectangular"`) and, when the value
applies only somewhere, a `context`. A context names the layout in `layoutIDWithFrameChainID`
(`steamVariantList:list: {int: <layout>}, {int: <frame chain>}, {bool: false}`), the block instance in
`blockInstanceID`, and sometimes a `propertyOffset` and `assignedStaveType`. A layout of -1 means every layout and a
block instance of -1 means any.

A `propertyOffset` of `0:<num>:<den>:0` puts a value partway through a note, `<num>/<den>` quarter notes from its
start. In Fauré's *Dolly* a note crosses a barline with `kNoteSpelling` `E` at `0:0:1:0` and `F` at `0:1:1:0`, so it
is written E sharp before the barline and F after it. The dump and the reader give the spelling at 0. Offsets starting
with 1, 2 or 3 appear on lines, slurs, pauses and divisi labels, and the reader doesn't interpret them.

How a value was set decides its context. The reading fixture's notes were set each way, then saved and decoded:

| Set by | Context stored |
| ------ | -------------- |
| `propertyTable:set` from Lua | none: every layout, any block instance |
| `EventEdit.ChangeProperty` with the event's ids | none |
| `Edit.SetNoteheadSetOverride` on a selection | layout -1 and the note's own block instance |
| `UI.InvokePropertyChangeValue` with a part on screen | that part's layout |
| `Edit.ShowAccidentalInBrackets` on a selection | the layout on screen: layout 0 with the full score showing, the part's layout with a part showing |

Other note properties the fixture holds: `kArticulationDuration` (`kStaccato`, `kTenuto`) and `kArticulationForce`
(`kAccent`) for articulations, `kNoteStringIndex` (`int: 4` for a guitar's fifth string; the fret follows from the
pitch and the tuning), `kNoteAccidentalVisibility_v3` (`kRoundBrackets`, `kSquareBrackets`) with the older
`kNoteAccidentalVisibility` written beside it, and `kBeamNone` on notes whose beams were broken.

## The library

`library` holds the definitions the project uses, each under an `entities` list. Every definition has an `entityID`,
which is what events and properties name, and a `name` to show a person:

| Collection | Example |
| ---------- | ------- |
| `paragraphStyles` | `paragraph.barnumbers.part` is "Bar numbers (parts)" |
| `playingTechniqueAppearanceCollectionDefinition` | `pta.pizzText` is "Pizzicato", shown as `pizz`, for the technique `pt.pizzicato` |
| `noteheadSetDefinitions` | `noteheadset.diamondNoteheads` is "Diamond Noteheads" |
| `instruments` | `instrument.wind.clarinet.bflat`, with its staves, clefs, ranges and transposition |

## Matching the file to Lua

A decoded `eventID` is the id Lua gives the same event, and a context's `blockInstanceID` is the "Start block id"
in `stream:dump()`. Stream ids and instrument ids are Lua's too.

`spikes/f2_compare.lua` checks this for every event, not only notes: it matched every event in every stream's dump to
the file, by id and position, in the reading fixture and in Fauré's *Dolly* (8,794 notes, 933 slurs, 288 dynamics and
the rest). *Dolly* was saved by 6.2.20 and opened in 6.2.30, so the ids survived the update Dorico makes when it opens
an older project, at least for that step. The handbells plug-in found the same for notes in two other projects
(1,079 and 2,365 of them).

## Adding a Dorico version

When a new Dorico comes out, `python tools/resave_fixtures.py` saves the fixtures in its format and runs the tests
([fixtures/README.md](../fixtures/README.md)).

- One test always fails on a new version's files: `every_fixture_is_a_known_format`, because the new `fileVersion`
  isn't in the `dorico6` profile's list yet. If that's the only failure, nothing the reader relies on changed. Add the
  number to the profile's list in [`lib/scorereader/format.lua`](../lib/scorereader/format.lua) and to the version
  table above, and commit the new fixtures folder.
- If a test fails, its message names the node, the value and the format. `spikes/f1_changes.lua`, run over the old
  and new fixtures, lists the paths that appeared or went, and `spikes/tree_dump.lua` shows any part of a tree.
- To teach the reader the change, add a profile to `format.PROFILES` with the new `fileVersion` and checks for the
  new structure, and let the reader that relies on the changed path branch on `s.format.profile.name`. Older
  profiles stay, so files the older versions saved keep reading.
