# Event streams

A stream of events: a voice, a staff, a player's, or the timebase.

Members come from `spikes/class_members.lua`'s scan of Lua's registry, sorted by `tools/members.py` into
[members.json](members.json). "Member" in the Kind column means the scan can't tell a property from a method, since
luabind stores both as functions, and nobody has tried it. Status says whether an example or probe has used a member
(verified), found it broken (fails), or left it alone (not tried). Don't try a member on a project you care about:
a bad call can crash Dorico.

## `DoCore.EventStream`

| Member | Kind | Status | Notes |
| ------ | ---- | ------ | ----- |
| `__eq` | operator | not tried |  |
| `__len` | operator | not tried |  |
| `__tostring` | operator | not tried |  |
| `addBlockInstance` | member | not tried |  |
| `blockInstances` | property | verified | The stream's block instances; `EventEdit.Select` needs one's `block.id` ([12-select-by-id](../../examples/fundamentals/12-select-by-id.lua)). |
| `copyRange` | method | fails | Copies nothing, within a flow or across flows. |
| `copyRangeLinked` | member | not tried |  |
| `createBarDivision` | member | not tried |  |
| `createBarRest` | member | not tried |  |
| `createClef` | member | not tried |  |
| `createDynamicGroup` | member | not tried |  |
| `createFrameBreak` | member | not tried |  |
| `createGraceNote` | member | not tried |  |
| `createNote` | method | verified | `createNote(position, duration, pitch)`, with RhythmicLength values and a MIDIPitchWithSpelling ([14-add-notes-rests-text](../../examples/fundamentals/14-add-notes-rests-text.lua)). |
| `createOttavaLine` | member | not tried |  |
| `createRest` | method | verified | `createRest(position, duration)` ([14-add-notes-rests-text](../../examples/fundamentals/14-add-notes-rests-text.lua)). |
| `createSystemBreak` | method | fails | Makes a break event that doesn't take effect; use `Edit.CreateSystemBreak`. |
| `createText` | method | verified | `createText(position, duration, text)`: a staff text above the staff ([14-add-notes-rests-text](../../examples/fundamentals/14-add-notes-rests-text.lua)). |
| `createTonalityDivision` | member | not tried |  |
| `createTransposingClef` | member | not tried |  |
| `createTuplet` | member | not tried |  |
| `delete` | method | verified | `delete(event)` removes an event ([proofread](../../examples/recipes/proofread.lua)). |
| `deleteEventsInRange` | method | verified | `deleteEventsInRange(from, to)` clears a range (the handbells plug-in). |
| `dump` | method | verified | Text, one line per event, on any stream ([03-read-notes](../../examples/fundamentals/03-read-notes.lua)). |
| `events` | property | verified | Event objects, but raises an error on a stream holding lyrics, slurs or other kinds with no Lua class ([S8](../spikes.md#s8-reading-and-setting-note-properties)). |
| `findBlockInstanceAtPoint` | member | not tried |  |
| `id` | property | verified | The stream's id. |
| `joinBlocks` | member | not tried |  |
| `moveRange` | member | not tried |  |
| `ossiaType` | member | not tried |  |
| `removeBlockInstance` | member | not tried |  |
| `splitStream` | member | not tried |  |
| `type` | property | verified | 0 timebase, 1 stave, 2 voice, 3 player. |
| `voiceDirection` | member | not tried |  |
