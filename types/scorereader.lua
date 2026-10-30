---@meta
-- Definitions for lib/scorereader, the reader library, for editors with lua-language-server. The classes are what
-- scorereader.score.read returns; docs/file-format.md says where each field comes from in a saved project.
--
-- The numeric ids (id, playerId, flowId, blockId and the rest) are the ones the file and Lua's object model share.
-- entityID is the library's string id for an instrument, such as "instrument.wind.clarinet.bflat".

-- A position or duration in quarter notes, in lowest terms: {num = 3, den = 2} is a dotted quarter.
---@class scorereader.Fraction
---@field num integer
---@field den integer

---@class scorereader.Format
---@field fileVersion string
---@field lastSavedVersion string
---@field known boolean
---@field profile {name: string, fileVersions: string[]}

---@class scorereader.Instrument
---@field id integer
---@field playerId integer
---@field entityID string
---@field name string
---@field staves integer
---@field range {standard: string|nil, advanced: string|nil}
---@field transposition {diatonic: integer, chromatic: integer, octaves: integer}|nil

---@class scorereader.Player
---@field id integer
---@field name string
---@field shortName string
---@field baseName string
---@field instruments scorereader.Instrument[]

---@class scorereader.Layout
---@field id integer
---@field name string
---@field number integer|nil
---@field type string kFullScoreLayout, kPartLayout or another of Dorico's layout types
---@field flowIds integer[]
---@field playerIds integer[]

---@class scorereader.Instance
---@field id integer
---@field blockId integer
---@field position scorereader.Fraction

---@alias scorereader.StreamType "timebase"|"stave"|"voice"|"player"|"automation"|"other"

---@class scorereader.Stream
---@field id integer
---@field type scorereader.StreamType
---@field rawType string
---@field playerId integer|nil
---@field instrumentId integer|nil
---@field staff integer|nil
---@field instances scorereader.Instance[]
---@field events scorereader.Event[]

---@class scorereader.Flow
---@field id integer
---@field title string
---@field info table<string, string>
---@field streams scorereader.Stream[]
---@field streamById table<integer, scorereader.Stream>
---@field options {accidentals: {durationBehaviour: string|nil, cautionary: table<string, string|boolean>, common: table<string, string|boolean>}|nil}
---@field events scorereader.Event[]
---@field elements table<string, table<integer, integer>> table name: {[elementID] = node}

---@class scorereader.Dynamic
---@field kind "immediate"|"gradual"|"force"|"combined"
---@field name string
---@field position scorereader.Fraction
---@field duration scorereader.Fraction|nil gradual only

---@class scorereader.Paragraph
---@field style string
---@field fragments {text: string, style: string|nil, localStyle: boolean}[]

---@alias scorereader.EventKind
---| "note"
---| "grace"
---| "rest"
---| "barRest"
---| "tuplet"
---| "slur"
---| "text"
---| "lyric"
---| "chordSymbol"
---| "dynamic"
---| "timeSignature"
---| "keySignature"
---| "tempo"
---| "rehearsalMark"
---| "playingTechnique"
---| "clef"
---| "other"
---@alias scorereader.ChordQuality "major"|"minor"|"augmented"|"diminished"
---@alias scorereader.ChordInterval ""|"7"|"maj7"|"6"|"9"|"11"|"13"

-- Every event has the fields down to node; the rest belong to the kinds named after them. The classes after this one
-- narrow an event of one kind, for code that has checked e.kind.
---@class scorereader.Event
---@field id integer
---@field kind scorereader.EventKind
---@field definition string
---@field flowId integer
---@field streamId integer
---@field blockId integer
---@field instanceId integer
---@field position scorereader.Fraction
---@field duration scorereader.Fraction
---@field node integer
---@field pitch integer|nil note, grace
---@field spelling string|nil note, grace: "F#5"
---@field notatedDuration scorereader.Fraction|nil grace
---@field slashed boolean|nil grace
---@field actual integer|nil tuplet
---@field normal integer|nil tuplet
---@field words string|nil text
---@field paragraphs scorereader.Paragraph[]|nil text
---@field above boolean|nil text, lyric
---@field system boolean|nil text
---@field formatted boolean|nil text
---@field text string|nil lyric, tempo, playingTechnique
---@field syllable "begin"|"middle"|"end"|"single"|nil lyric
---@field line integer|nil lyric
---@field lineType "verse"|"chorus"|nil lyric
---@field root string|nil chordSymbol, keySignature
---@field quality scorereader.ChordQuality|nil chordSymbol
---@field interval scorereader.ChordInterval|nil chordSymbol
---@field rawQuality string|nil chordSymbol
---@field rawInterval string|nil chordSymbol
---@field altered boolean|nil chordSymbol
---@field name string|nil chordSymbol, playingTechnique
---@field dynamics scorereader.Dynamic[]|nil dynamic
---@field numerator integer|string|nil timeSignature
---@field denominator integer|nil timeSignature
---@field barlineOnly boolean|nil timeSignature
---@field barline string|nil timeSignature
---@field pickup scorereader.Position|nil timeSignature: the length of a short first bar
---@field mode "major"|"minor"|"atonal"|"custom"|nil keySignature
---@field atonal boolean|nil keySignature
---@field fifths integer|nil keySignature
---@field accidentalID string|nil keySignature
---@field type string|nil tempo: kAbsolute, kRelative or another of Dorico's tempo types
---@field preset string|nil tempo
---@field bpm integer|nil tempo
---@field microsecondsPerBeat integer|nil tempo
---@field appearance string|nil playingTechnique
---@field technique string|nil playingTechnique
---@field clef string|nil clef

---@class scorereader.NoteEvent: scorereader.Event
---@field kind "note"|"grace"
---@field pitch integer
---@field spelling string

---@class scorereader.GraceNoteEvent: scorereader.NoteEvent
---@field kind "grace"
---@field notatedDuration scorereader.Fraction
---@field slashed boolean

---@class scorereader.TupletEvent: scorereader.Event
---@field kind "tuplet"
---@field actual integer
---@field normal integer

---@class scorereader.TextEvent: scorereader.Event
---@field kind "text"
---@field words string
---@field paragraphs scorereader.Paragraph[]
---@field above boolean
---@field system boolean
---@field formatted boolean

---@class scorereader.LyricEvent: scorereader.Event
---@field kind "lyric"
---@field text string
---@field syllable "begin"|"middle"|"end"|"single"
---@field line integer
---@field lineType "verse"|"chorus"
---@field above boolean

-- quality and interval are nil for a value the reader has no name for; rawQuality and rawInterval always hold
-- Dorico's own. name is there only for the chords checked against Dorico's names.
---@class scorereader.ChordSymbolEvent: scorereader.Event
---@field kind "chordSymbol"
---@field root string
---@field rawQuality string
---@field rawInterval string
---@field altered boolean

---@class scorereader.DynamicEvent: scorereader.Event
---@field kind "dynamic"
---@field dynamics scorereader.Dynamic[]

-- Either numerator and denominator, or barlineOnly.
---@class scorereader.TimeSignatureEvent: scorereader.Event
---@field kind "timeSignature"

-- root, fifths and accidentalID are nil for an atonal key; root and fifths for a key outside the 12-note system too.
---@class scorereader.KeySignatureEvent: scorereader.Event
---@field kind "keySignature"
---@field mode "major"|"minor"|"atonal"|"custom"
---@field atonal boolean

-- bpm and microsecondsPerBeat only for an absolute tempo.
---@class scorereader.TempoEvent: scorereader.Event
---@field kind "tempo"
---@field text string

---@class scorereader.PlayingTechniqueEvent: scorereader.Event
---@field kind "playingTechnique"
---@field appearance string
---@field name string

---@class scorereader.ClefEvent: scorereader.Event
---@field kind "clef"

---@class scorereader.Score
---@field format scorereader.Format
---@field info table<string, string>
---@field library table<string, {name: string, node: integer}>
---@field players scorereader.Player[]
---@field instruments table<integer, scorereader.Instrument>
---@field layouts scorereader.Layout[]
---@field flows scorereader.Flow[]
---@field flowById table<integer, scorereader.Flow>
---@field events table<integer, scorereader.Event>
---@field tree table the decoded tree the score was read from
---@field cache table<scorereader.Event, scorereader.PropertyEntry[]> the property entries read so far

-- One property entry: value is the raw typed text ('string: "C"'), and layout, frameChain and instance are -1 for
-- every layout, any frame chain and any block instance.
---@class scorereader.PropertyEntry
---@field property string
---@field value string
---@field layout integer
---@field frameChain integer
---@field instance integer
---@field offset string|nil
---@field staveType string|nil

---@class scorereader.score
---@field read fun(input: string|table): scorereader.Score
---@field readFile fun(path: string): scorereader.Score
---@field eventsOf fun(s: scorereader.Score, flow: scorereader.Flow, player: scorereader.Player): scorereader.Event[]
---@field ownerOf fun(s: scorereader.Score, e: scorereader.Event): scorereader.Player|nil
---@field partOf fun(s: scorereader.Score, player: scorereader.Player): scorereader.Layout|nil
---@field fullScoreOf fun(s: scorereader.Score): scorereader.Layout|nil
---@field entries fun(s: scorereader.Score, e: scorereader.Event): scorereader.PropertyEntry[]
---@field value fun(s: scorereader.Score, e: scorereader.Event, property: string, layoutId: integer): any, boolean
---@field above fun(s: scorereader.Score, e: scorereader.Event, layoutId: integer): boolean|nil

---@class scorereader.dorico.savedcopy
---@field read fun(app: DoApp, opts: {dir: string|nil, log: fun(line: string)|nil, remove: function|nil}|nil): scorereader.Score

---@class scorereader.dorico.edit
---@field select fun(app: DoApp, e: scorereader.Event)
---@field setProperty fun(app: DoApp, e: scorereader.Event, property: string, value: string)
---@field removeProperty fun(app: DoApp, e: scorereader.Event, property: string)
---@field delete fun(app: DoApp, e: scorereader.Event)
---@field blockIdOf fun(stream: EventStream, eventId: integer, parsed: scorereader.dorico.Dump): integer

-- An event line of stream:dump(). pos and duration are quarter notes as numbers; instance is the block instance the
-- line follows.
---@class scorereader.dorico.DumpEvent
---@field kind "note"|"grace"|"rest"|"text"|"other"
---@field id integer
---@field pos number|nil
---@field duration number|nil
---@field spelling string|nil note, grace
---@field grace boolean
---@field text string|nil text
---@field instance integer|nil
---@field raw string

---@class scorereader.dorico.Dump
---@field events scorereader.dorico.DumpEvent[]

---@class scorereader.dorico.dump
---@field event fun(text: string|nil, instance: integer|nil): scorereader.dorico.DumpEvent|nil
---@field parse fun(text: string|nil): scorereader.dorico.Dump
---@field notes fun(parsed: scorereader.dorico.Dump): scorereader.dorico.DumpEvent[]

---@class scorereader.dorico.Match
---@field byId table<integer, {file: scorereader.Event, lua: scorereader.dorico.DumpEvent}>
---@field count integer
---@field unmatched string[]

---@class scorereader.dorico.match
---@field stream fun(s: scorereader.Score, flowId: integer, streamId: integer, parsed: scorereader.dorico.Dump): scorereader.dorico.Match

---@class scorereader.dorico.commands
---@field value fun(v: any): string
---@field build fun(name: string, params: {[1]: string, [2]: any}[]|nil): string
---@field select fun(flowId: integer, eventId: integer, blockId: integer): string
---@field changeProperty fun(flowId: integer, eventId: integer, blockId: integer, property: string, value: any): string
---@field removeProperty fun(flowId: integer, eventId: integer, blockId: integer, property: string): string
