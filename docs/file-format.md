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

### Players

A `scorePlayer` has a `playerID`, `displayName` and `displayShortName` (the names Dorico shows), `baseName`,
`soloPlayer`, and `instruments`, a list of `instrument` nodes.

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
  on).

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
`MultiRestEventDefinition`. None of the 52 projects has a chord symbol or a tab staff.

A text event's words are in `content/paragraphs/paragraph`, which has a `paragraphStyleID` and `fragments`. Each
`fragment` has its words in `content` and its formatting in `textFragmentStyle`.

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

## Matching the file to Lua

A decoded `eventID` is the id Lua gives the same event, and a context's `blockInstanceID` is the "Start block id"
in `stream:dump()`. The handbells plug-in found this on two real projects, where all 1,079 and all 2,365 dumped notes
matched a decoded note with the same position and pitch.
