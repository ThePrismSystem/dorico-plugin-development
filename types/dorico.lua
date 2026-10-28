---@meta
-- Definitions for Dorico 6's Lua object model, for editors with lua-language-server (sumneko). They cover
-- the classes in docs/reference; types are given where an example or probe showed them. Dorico doesn't
-- publish this API; see docs/guide.md.

---@class DoApp
---@field currentLayoutID integer
---@field currentScore Score|nil
---@field doCommand fun(self: DoApp, command: string)
---@field open any
---@field save any
---@field versionString string

---@class DoUI
---@field showFolderChooser any

---@class Score
---@field addEnsemble any
---@field addPlayer fun(self: Score, instrument: string, flag: boolean, count: integer): Player
---@field flowIDs any
---@field flows Flow[]
---@field instruments any
---@field layouts Layout[]
---@field libraries any
---@field openScoreID integer
---@field players Player[]
---@field title string

---@class ScoreLibraries
---@field brushstyles any
---@field clefs any
---@field ensembles any
---@field fontstyles any
---@field instruments any
---@field ottavaLines any
---@field penstyles any

---@class Flow
---@field addPlayer fun(self: Flow, player: Player)
---@field allStreams EventStream[]
---@field elementTables FlowElements
---@field id integer
---@field instruments FlowInstrument[]
---@field playerStreams EventStream[]
---@field players Player[]
---@field removePlayer fun(self: Flow, player: Player)
---@field staveStreams EventStream[]
---@field timebaseStreams EventStream[]
---@field voiceStreams EventStream[]

---@class FlowElements
---@field barDivisions BarDivisionTable
---@field dynamics DynamicTable
---@field tonalityDivisions any

---@class BarDivisionTable
---@field createBarDivisionElement any
---@field elements any

---@class DynamicTable
---@field createDynamicGroup any
---@field elements any

---@class DynamicGroupElement
---@field createEvent any
---@field createImmediateChange any
---@field events any
---@field id any
---@field propertyTable any
---@field subElements any

---@class Player
---@field instruments Instrument[]

---@class Instrument
---@field id integer
---@field name any

---@class FlowInstrument
---@field id integer
---@field name any
---@field streams any

---@class Layout
---@field addFlow any
---@field addPlayer fun(self: Layout, player: Player)
---@field id integer
---@field players Player[]
---@field removeFlow fun(self: Layout, flow: Flow)
---@field removePlayer any

---@class EventStream
---@field addBlockInstance any
---@field blockInstances EventBlockInstance[]
---@field copyRange any
---@field copyRangeLinked any
---@field createBarDivision any
---@field createBarRest any
---@field createClef any
---@field createDynamicGroup any
---@field createFrameBreak any
---@field createGraceNote any
---@field createNote fun(self: EventStream, position: RhythmicLength, duration: RhythmicLength, pitch: MIDIPitchWithSpelling): Event
---@field createOttavaLine any
---@field createRest fun(self: EventStream, position: RhythmicLength, duration: RhythmicLength): Event
---@field createSystemBreak any
---@field createText fun(self: EventStream, position: RhythmicLength, duration: RhythmicLength, text: string): Event
---@field createTonalityDivision any
---@field createTransposingClef any
---@field createTuplet any
---@field delete fun(self: EventStream, event: Event)
---@field deleteEventsInRange fun(self: EventStream, from: RhythmicLength, to: RhythmicLength)
---@field dump fun(self: EventStream): string
---@field events Event[]
---@field findBlockInstanceAtPoint any
---@field id integer
---@field joinBlocks any
---@field moveRange any
---@field ossiaType any
---@field removeBlockInstance any
---@field splitStream any
---@field type integer
---@field voiceDirection any

---@class Event
---@field duration any
---@field endPosition any
---@field id integer
---@field position any
---@field propertyTable EventPropertyTable

---@class NoteEvent
---@field duration any
---@field endPosition any
---@field id any
---@field pitchWithSpelling any
---@field position any
---@field propertyTable any

---@class GraceNoteEvent
---@field duration any
---@field endPosition any
---@field id any
---@field pitchWithSpelling any
---@field position any
---@field propertyTable any
---@field secondaryPosition any

---@class RestEvent
---@field duration any
---@field endPosition any
---@field id any
---@field position any
---@field propertyTable any

---@class BarRestEvent
---@field duration any
---@field endPosition any
---@field id any
---@field position any
---@field propertyTable any

---@class TextEvent
---@field duration any
---@field endPosition any
---@field id any
---@field position any
---@field propertyTable any
---@field text any

---@class TupletEvent
---@field duration any
---@field endPosition any
---@field id any
---@field position any
---@field propertyTable any
---@field tupletDef any

---@class ClefEvent
---@field duration any
---@field endPosition any
---@field id any
---@field nonTransposingClefEntity any
---@field position any
---@field propertyTable any
---@field transposingClefEntity any

---@class OttavaLineEvent
---@field duration any
---@field endPosition any
---@field id any
---@field ottavaLineDefinitionID any
---@field position any
---@field propertyTable any

---@class BreakEvent
---@field duration any
---@field endPosition any
---@field id any
---@field isFrameBreak any
---@field isSystemBreak any
---@field layoutID any
---@field position any
---@field propertyTable any

---@class BarDivisionEvent
---@field duration any
---@field endPosition any
---@field id any
---@field position any
---@field propertyTable any

---@class TonalityDivisionEvent
---@field duration any
---@field endPosition any
---@field id any
---@field position any
---@field propertyTable any
---@field tonalityDivisionElementID any

---@class DynamicGroupEvent
---@field duration any
---@field endPosition any
---@field id any
---@field position any
---@field propertyTable any

---@class EventBlockInstance
---@field block EventBlock
---@field events any
---@field id integer
---@field position any

---@class EventBlock
---@field events any
---@field id integer

---@class EventPropertyTable
---@field get fun(self: EventPropertyTable, name: string, context: PropertyContext): Variant
---@field getPropertyNames fun(self: EventPropertyTable): string[]
---@field set fun(self: EventPropertyTable, name: string, value: Variant, context: PropertyContext): boolean

---@class EventPropertyEntry
---@field context any
---@field name any
---@field value any

---@class PropertyContext

---@class RhythmicLength
---@field denominator any
---@field numerator any

---@class MIDIPitchWithSpelling
---@field accidentalType any
---@field multitonalFraction any
---@field noteName any
---@field octave any
---@field pitch any

---@class Variant
---@field toBool any
---@field toDouble any
---@field toInt any
---@field toString any
---@field type integer
---@field valid boolean

---@class NoteName

---@class MIDIPitch

---@class ScriptHost
---@field convertFolderOfScores any
---@field createNewScore any
---@field currentScore any
---@field engine any
---@field open any
---@field save any
---@field showFolderChooser any

---@class DoAppNamespace
---@field DoApp fun(): DoApp

---@type DoAppNamespace
DoApp = {}

---@class DoCoreNamespace
---@field RhythmicLength fun(numerator: integer, denominator?: integer): RhythmicLength
---@field PropertyContext fun(): PropertyContext
---@field MIDIPitchWithSpelling { fromString: fun(spelling: string): MIDIPitchWithSpelling }
---@field Variant { createString: fun(text: string): Variant, createBool: fun(b: boolean): Variant, createInt: fun(n: integer): Variant, createDouble: fun(x: number): Variant }

---@type DoCoreNamespace
DoCore = {}
