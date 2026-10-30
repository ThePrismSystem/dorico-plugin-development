# Writing Lua scripts for Dorico 6

A field guide to the parts of Dorico 6's Lua scripting that Steinberg doesn't document: how a script reads the
music, changes the score, asks the user something and is tested from outside Dorico, and the workarounds and gotchas
found along the way. Each technique points at the example in this repository that shows it working.

It began as the guide to the [Handbells Used Chart plug-in](https://github.com/ThePrismSystem/handbells-used-chart-dorico),
which is still the full-sized example: a plug-in with a dialog, a pure-Lua core with unit tests, and an in-Dorico
test suite. This copy is general, and adds what this repository's probes found. Their evidence is in
[spikes.md](spikes.md), and the probes themselves are in `spikes/`.

Everything here was seen on Dorico 6.2.30 on Windows 11. The Mac parts are written from Apple's documentation and
haven't been run on a Mac. None of this is a published API, and Steinberg can change any of it in any update, so
check each call on the version you target.

## Contents

1. [How a script runs](#1-how-a-script-runs)
2. [The object model](#2-the-object-model)
3. [Reading the music](#3-reading-the-music)
4. [The text export](#4-the-text-export)
5. [Changing the score](#5-changing-the-score)
6. [Commands](#6-commands)
7. [Undo, redo and saving](#7-undo-redo-and-saving)
8. [Asking the user](#8-asking-the-user)
9. [Running a script from a key](#9-running-a-script-from-a-key)
10. [Working through other projects](#10-working-through-other-projects)
11. [Testing from outside Dorico](#11-testing-from-outside-dorico)
12. [Gotchas, in one list](#12-gotchas-in-one-list)
13. [Which example shows what](#13-which-example-shows-what)

## 1. How a script runs

### Where scripts go

Script > Run Script runs any `.lua` file. To have a script in the Script menu, put it at the top level of the
Script Plug-ins folder and restart Dorico:

- Windows: `%APPDATA%\Steinberg\Dorico 6\Script Plug-ins\`
- Mac: `~/Library/Application Support/Steinberg/Dorico 6/Script Plug-ins/` (not confirmed on a Mac)

Dorico doesn't look in subfolders, so a plug-in made of several modules puts one entry file at the top level and its
modules in a folder beside it. The entry file finds that folder from its own path:

```lua
local here = debug.getinfo(1, "S").source:match("^@(.*[/\\])")
local root = here .. "My Plug-in/"
```

The examples here are single files with no modules, so any of them runs from Script > Run Script as it is. DoricoUse
found a second kind of plug-in in Dorico's binary, a folder holding an `Info.lua` with `MenuCommands`; it's
described in [spikes.md](spikes.md) (S7) and wasn't tried here. Whether Dorico notices a new plug-in of either kind
without a restart wasn't checked either, so restart to be sure.

### Where print goes

`print` writes to Dorico's Script Console (Script > Show Script Console). Lines printed while the console is closed
are kept, and appear when it opens. `io.write` output goes nowhere. A script can open the console itself with
`app:doCommand("Script.ShowConsole")`, but that command toggles: run it in every run and every second run closes the
console. The examples print and leave the console alone.

### One Lua state for the whole session

Dorico keeps a single Lua state from launch to quit. Globals and `package.loaded` survive from one script run to the
next. Three things follow:

- Make everything `local`. A global set by one run is still there for the next, which is how
  [19-key-command.lua](../examples/fundamentals/19-key-command.lua) counts its runs and
  [hotkey-colour-cycle.lua](../examples/recipes/hotkey-colour-cycle.lua) remembers its colour, and a trap for
  anything else. Give a global you mean to keep a name no other script would choose.
- A plug-in with modules should clear them from `package.loaded` at the start of every run. Otherwise `require`
  hands back the version loaded by an earlier run, and an edited module doesn't take effect until Dorico restarts.
- Add to `package.path` only once. Prepending a folder on every run makes the path grow without end.

```lua
for name in pairs(package.loaded) do
  if name:match("^myplugin") then package.loaded[name] = nil end
end
local mine = root .. "?.lua"
if not package.path:find(mine, 1, true) then package.path = mine .. ";" .. package.path end
```

### Errors are quiet

- A script with a syntax error is skipped without a word. Dorico doesn't run it, log it or report it. Run
  `luac -p` (Lua 5.2's compiler) over a file before trying a change in Dorico.
- A runtime error ends the script. For anything a user will run, wrap the work in `pcall` or `xpcall` and tell the
  user what went wrong in a way they'll see.
- `debug.traceback(err)` returns a non-string error unchanged, with no traceback. Turn error tables into text first.

### What Lua has

- Lua 5.2, with the standard `io`, `os`, `string`, `table`, `math` and `debug` libraries.
- On Windows, `require("lfs")` (LuaFileSystem) works, since Dorico ships `lfs.dll`. Whether a Mac has it is unknown.
- No user interface. Section 8 is how to get one.
- `os.execute` runs a command, and Dorico waits, frozen, until it returns.

### Two ways in

Everything a script does goes through one of two doors:

- The object model: `DoApp`, `DoCore` and their classes, C++ bound to Lua with luabind. It reads the score's
  structure and notes, and it can create notes, rests, texts and players and set event properties.
- Commands: `app:doCommand("Name?key=value&...")`, the same commands Dorico's menus and key commands run. They do
  what the object model can't: selections, flows, layout options, chord symbols, saving.

Most real tasks need both: read with the object model, select with a command, then change something with a command
on the selection or through the object model.

### Finding out what exists

- The bound classes are in Lua's registry, and a script can walk it to list every class and member.
  `spikes/class_members.lua` does, and [the reference](reference/README.md) is built from what it finds; the handbells
  repository's `spike/17_api_map.lua` found `NoteEvent.pitchWithSpelling`, `EventStream.type`, `Flow.elementTables`
  and `Score.title` the same way. DoricoUse maps the same object model independently.
- Command names come from Dorico's own key-command file, `keycommands_en.json` in its program folder, from
  `application.log` in `%APPDATA%\Steinberg\Dorico 6`, which records the command behind each menu item and popover
  you use, and from the Remote Control API's `getcommands`. A command string Dorico logs works from Lua as it is.
- Everything else came from probes: small scripts that try one thing on a scratch copy and write down what
  happened. Don't call unknown methods blind on a project you care about: a constructor given bad arguments can
  crash Dorico.

## 2. The object model

```lua
local app = DoApp.DoApp()
local ok, score = pcall(function() return app.currentScore end)   -- nil, or perhaps an error, with no project open
```

Every example starts with that check, as its `guard` helper, so with no project open it says "Open a project first"
([01-hello.lua](../examples/fundamentals/01-hello.lua)). Every class and member a scan of Lua's registry found is in
[the reference](reference/README.md), each marked verified, failing or not tried; the table here is the short
version.

| Object | What we used | What it doesn't have |
| ------ | ------------ | -------------------- |
| App | `versionString`, `currentScore`, `currentLayoutID`, `doCommand(text)` (returns nothing) | |
| Score | `flows`, `players`, `layouts`, `openScoreID` (for commands), `title`, `addPlayer(instrument, false, 1)` | the file path, any way to delete a player |
| Flow | `id`, `players`, `voiceStreams`, `staveStreams`, `allStreams`, `instruments`, `elementTables`, `removePlayer` | a title |
| Player | `tostring(player)` (its name), `instruments` | an id, `==` |
| Instrument | `id` | a name, its type, its transposition |
| Layout | `id`, `players`, `removeFlow` | a name, any option |
| EventStream | `events`, `dump()`, `blockInstances`, `createNote`, `createRest`, `createText`, `delete`, `type`, `id` | |
| Block instance | `id` (the dump's "Start block id"), `block.id` (what `EventEdit.Select` takes) | |
| Event | `id`, `propertyTable`, `tostring(event)` | |

What Lua can't read, and the way round it:

| Missing | Workaround |
| ------- | ---------- |
| A flow's title, an instrument's name, the project's file path | The text export (section 4, [05-names-from-the-text-export.lua](../examples/fundamentals/05-names-from-the-text-export.lua)) |
| A player's id, which commands need | Rename candidates to a unique token and see which player takes it ([16-flows-and-players.lua](../examples/fundamentals/16-flows-and-players.lua)) |
| Which player a voice belongs to | `flow.instruments[i]` owns `flow.voiceStreams[i]` ([02-walk-the-score.lua](../examples/fundamentals/02-walk-the-score.lua)) |
| The selection | Move it by command and see what moved (section 3) |
| An event looked up by id | Keep the ids from `dump()` and select them by command (section 5) |
| Layout and notation options | Set them by command; learn a value from the text export (section 5) |
| Time signatures, key signatures, bar numbers | Bar numbers from the text export (section 4); the others not at all |
| An instrument's transposition | Ask the user, or set it in the script ([label-notes.lua](../examples/recipes/label-notes.lua)) |

### Ids and identity

- Players have no `==`. Comparing two raises "No such operator defined". Compare `player.instruments[1].id`,
  which is unique and stays the same.
- Player ids are not instrument ids. Commands such as `Project.Player.Rename` take a player id, which Lua doesn't
  expose. In a project made in Dorico a player's id is usually its first instrument's id. In Steinberg's own Smith
  example it isn't, so check.
- `flow.instruments[i].id` owns `flow.voiceStreams[i]`: one entry per voice stream, in the same order. This held on
  every project tried, including a piano with three voices. `flow.instruments[i].streams` looks like the obvious
  route, but it returns streams only for the first instrument.
- Stream `type` is 0 for the timebase stream, 1 for a stave, 2 for a voice and 3 for a player.
- Layout and flow ids are the same ids the Remote Control API takes. In a fresh project, layout 0 is the full score.
  To find the full score in general, take the layout that holds every player with the lowest id
  ([15-layout-and-notation-options.lua](../examples/fundamentals/15-layout-and-notation-options.lua)).
- `tostring(player)` is the name the Setup panel shows, except that music symbols come out as tokens: a B-flat
  trumpet is `Trumpet (B{@flat@})`. The text export names the same player's instrument `Trumpet`, without the
  transposition.

### Properties

Events carry their details in a property table, read and written through `DoCore` values:

```lua
local ctx = DoCore.PropertyContext()
local head = tostring(note.propertyTable:get("kNoteheadSetOverride", ctx))   -- "" when not set
note.propertyTable:set("kNoteHideStem", DoCore.Variant.createString("true"), ctx)
```

- `get` returns a Variant, and `tostring(variant)` gives its value. An unset property reads as `""`.
- `getPropertyNames()` lists only the properties an event has.
- `set` returns `true` when Dorico took the value, which doesn't always mean anything changed (section 5).
- A colour set by command (or in the Properties panel) is listed but reads as `""`: its Variant has `valid` false.
  A colour set through the property table reads back as the string it was set to, after a save and reopen too. But
  once a command recolours that note, the page shows the new colour and Lua still reads the old string.

## 3. Reading the music

### `tostring(event)` and pitch

`tostring(event)` describes an event: `kNoteEvent (id:7932) at 0, duration 1  E5 (ends 1)`. Positions and
durations are in quarter notes from the start of the flow, as exact fractions where they need them
(`3/2 (1.5)`). A tuplet's notes carry their real lengths: a triplet eighth is `duration 1/3`, not the eighth it's
written as. Every pitch is sounding pitch: a B-flat trumpet's written D5 is `C5` here, and nothing in Lua says how an
instrument transposes.

### `stream.events` fails on real music

`stream.events` gives event objects, but it raises an error on any stream that holds a kind of event with no Lua
class: lyrics, slurs, hairpins, playing techniques. Most real music has at least one of those.

### `stream:dump()` always works

`stream:dump()` returns text, one line per event, on any stream:

```
Start block id: 1061 position: 0
0 (0) dur: 1: kNoteEvent (id:7932) at 0, duration 1  E5 (ends 1)
8 (8): kGraceNoteEvent (id:200) at 8  secondary pos -1/2 (-0.5), notated duration: 1/2 (0.5), B6
```

Each event line ends in what `tostring(event)` gives. The `dump` helper parses it into tables
([03-read-notes.lua](../examples/fundamentals/03-read-notes.lua)), and every example that reads notes carries a copy.
The `Start block id` is, despite its name, a block instance id, and the events after it belong to that instance;
selecting an event needs it (section 5).

What the dump shows and doesn't:

- Voice streams hold notes, grace notes, tuplets (`kTupletEvent`, such as `3:2, unit = e`), slurs (`kSlurEvent`, with
  a duration) and lyrics (`kLyricEvent`). Stave streams hold clefs and dynamics. The timebase stream holds a
  `kBarDivisionEvent` for each time signature, a `kTonalityDivisionEvent` for each key signature, and chord symbols,
  named in full (`kChordSymbolEvent (id:326) at 12  G7`).
- Ties aren't events: a tied note is one note with the whole length.
- Implicit rests aren't listed, and rests removed with Edit > Remove Rests leave no trace, so a script can't find
  an incomplete bar.
- No properties: no notehead, no colour.

`flow.elementTables` reaches a little further. Dynamics can be read there (each sub-element has
`kDynamicImmediateChangeBasicType` and `kDynamicImmediateChangeIsMezzo`). Time signatures can't
(`kBarDivisionTimeSignatures` fails with "Invalid conversion"), and key signatures can't either
(`tonalityDivisions` raises "Trying to use unregistered class").

### Noteheads and colours: read a pasted copy

To read properties from a stream that `stream.events` refuses, copy the music into a temporary flow that holds only
notes, read that, and take it away again ([04-noteheads-and-colours.lua](../examples/fundamentals/04-noteheads-and-colours.lua)):

1. `Project.Flow.New` adds a flow at the end. It holds every player, so remove the players the music flow doesn't
   have with `flow:removePlayer`.
2. Select the music flow's whole range: `EventEdit.Select` its first note, then `Edit.SelectToStartOfFlow`,
   `Edit.SelectAtEndOfFlow`, and `EventEdit.NavigateDownExtend` once for each staff after the first.
3. `Filter.NotesAndChords`, then `Edit.Copy`.
4. In the new flow, create a temporary note at position 0 in the voice of the instrument the copied range starts
   with, `EventEdit.Select` it, and `Edit.Paste`. That's the first voice unless the flow's first players are tacet;
   pasting onto the first voice then puts every staff's notes one player too high, with no error.
5. The filter keeps note-attached lines such as slurs, and those still stop `stream.events`. Delete each event in
   the copy whose kind has no Lua class: select it by id, then `Edit.Delete`.
6. Now `stream.events` and `propertyTable:get` work. Skip the temporary note by its id.
7. Take the temporary flow away with one `Edit.Undo` (section 7 says why exactly one).

Try `stream.events` first and copy only the flows where it fails. The paste merges unisons in two voices on one
staff and lists a chord's notes in a different order each time, so sort them. It also replaces the clipboard and the
selection, which users should be told.

### The selection

Lua can't ask what's selected, but the selected notes are the ones a command moves
([11-act-on-the-selection.lua](../examples/fundamentals/11-act-on-the-selection.lua)):

1. Dump every voice.
2. `NoteEdit.PitchUpOctave`, then dump again. The notes whose spelling changed are the selection.
3. `NoteEdit.PitchDownOctave` puts them back.

Use octaves. A semitone up and down (`NoteEdit.PitchUpChromatic`, `NoteEdit.PitchDownChromatic`) respells: G#4 comes
back as Ab4. An octave keeps the letter and the accidental, Fb4 and Dx4 included. Moving back keeps the run free of
an `Edit.Undo`, which would take back everything the run had done and join whatever it did next to the user's last
undo step (section 7). The route finds notes and grace notes only, and misses a note that
can't go an octave higher. The Remote Control API's status (`hasSelection`, `selectedEventType`) says what kind of
thing is selected, but only to a program outside Dorico.

## 4. The text export

```lua
app:doCommand("File.Export.Text?File=C:/temp/out.txt&Show=false")   -- writes C:/temp/out.csv
```

`File.Export.Text` writes a CSV of every text in the project, silently, beside the name it's given (with `.csv` in
place of `.txt`). Its columns are `Path, ID, FlowNumber, FlowName, Instrument, Page, Bar, Type, Text, Hidden`. The
`export` helper runs it and reads the rows ([05-names-from-the-text-export.lua](../examples/fundamentals/05-names-from-the-text-export.lua)).
It's the window onto several things Lua can't read:

- The project's file path: every row's `Path`, empty until the project is saved.
- The project's title: the `Project Info (Title)` row. Flow titles: the `Flow Info (Title)` rows, by `FlowNumber`.
- Instrument names. An instrument appears only in the rows of texts on its staff, so put a marker text in a voice
  of each instrument with `stream:createText`, export, read each marker's `Instrument`, and delete the markers with
  `stream:delete`. The `ID` column is `<flow>-<stream>-<event>`, counting flows from 0.
- Bar numbers. Every row has its `Bar`. A marker at a position tells you the bar it's in, and markers at the quarter
  notes before it tell you where that bar starts, so a script can report "bar 2, beat 3" without reading a time
  signature ([proofread.lua](../examples/recipes/proofread.lua)).
- Layout options, indirectly. A flow heading is a `Text Frame` row, there only while headings show, so comparing
  exports shows whether a change took ([15-layout-and-notation-options.lua](../examples/fundamentals/15-layout-and-notation-options.lua)).
  To learn an option's value, export again under each candidate and see which matches. With a single flow, two of
  `flowHeadingBehaviour`'s three values look the same.

Quirks:

- Fields can hold quoted commas, doubled quotes and newlines. Read the CSV with a quote-aware reader.
- Read a missing column as empty, and skip blank lines.
- Some projects export their flow titles with no `FlowNumber`, in alphabetical order (Steinberg's Smith example).
  Then you know only the set of titles.
- That project exported no hidden texts at all, so don't count on finding a hidden marker.

## 5. Changing the score

### Notes, rests and text

```lua
local RL = DoCore.RhythmicLength
voice:createNote(RL(4), RL(1), DoCore.MIDIPitchWithSpelling.fromString("Ab5"))
voice:createRest(RL(10), RL(1))
voice:createText(RL(0), RL(1), "label")   -- staff text above the staff
```

- `RhythmicLength(n)` keeps only the whole part of n: `RL(0.5)` is 0. A fraction goes in as
  `RhythmicLength(numerator, denominator)`, so 1.5 quarter notes is `RL(3, 2)` and 7/3 is `RL(7, 3)`. The `length`
  helper turns a number of quarter notes into one ([14-add-notes-rests-text.lua](../examples/fundamentals/14-add-notes-rests-text.lua)).
- `fromString` takes a sounding spelling, `<letter><accidentals><octave>`, and the note keeps exactly that spelling.
- A constructor given bad arguments can crash Dorico. Never pass `fromString` a pitch above MIDI 127, or anything
  you haven't checked parses.
- Two `createNote` calls at one position in one voice make a chord. A grand-staff player's voices are listed treble
  first.
- A new flow has no time signature, so it is one long bar.

### Properties that work when set

| Property | Value | Effect |
| -------- | ----- | ------ |
| `kNoteHideStem` | `"true"` | hides the stem |
| `kNoteheadSetOverride` | a set id, such as `noteheadset.diamondNoteheads` | draws the note in that notehead set |
| `kEventColour` | `#aarrggbb` or `#rrggbb` | colours the note |
| `kTextHide` | `"true"` | hides a text (it shows as a signpost in Write mode, and doesn't print) |
| `kTimeSignatureHide` | `"true"`, on the bar-division event | hides a time signature |
| `kNoteHideNotehead`, `kNoteLedgerLineHide` | `"true"` | with a hidden stem, makes an invisible note |

Set them with `DoCore.Variant.createString(...)` on an event from `stream.events`. Notehead sets used:
`noteheadset.default`, `noteheadset.diamondNoteheads`, `noteheadset.rectangular`,
`noteheadset.triangleUpNoteheads`, `noteheadset.triangleDownNoteheads`, `noteheadset.Xnoteheads`.

### Properties by command

A command changes the selected items, through the Properties panel's own route:

```
UI.InvokePropertyChangeValue?Type=kEventColour&Value=#ffff0000
```

That colours the selection ([12-select-by-id.lua](../examples/fundamentals/12-select-by-id.lua),
[colour-by-pitch.lua](../examples/recipes/colour-by-pitch.lua)). The same command with `kNoteheadSetOverride` changed
nothing.

### Properties that don't work

- `kEventHide` hides neither texts nor rests. Use `kTextHide` for texts. For rests, don't create them; remove them
  by command.
- Naturals can't be hidden by property: `kNoteAccidentalVisibility` takes the value and nothing changes. Select the
  note and run `Edit.HideAccidental`, once per note.

### Selecting an event for a command

```
EventEdit.Select?FlowID=<flow.id>&EventID=<event id>&EventBlockID=<block id>
```

The block id is the id of the block holding the event. Find the event's instance (the `Start block id` above it in
the dump) in `stream.blockInstances`, and take that instance's `block.id`. The `blockIdOf` helper does this
([12-select-by-id.lua](../examples/fundamentals/12-select-by-id.lua)).

- In many projects the block id happens to be the instance id minus 1000, but in a downloaded arrangement instance
  1061 held block 36, so look it up every time. A select given the wrong block id selects nothing and reports
  nothing, and the commands after it act on nothing too.
- A second `EventEdit.Select` replaces the selection. To act on several notes, select and act on each in turn, or
  select the first and extend with `EventEdit.NavigateRightExtend`.
- Leave note input (`NoteInput.Exit`) and switch to Write mode (`Window.SwitchMode?WindowMode=kWriteMode`) before
  selecting. `Edit.SelectNone` clears the selection.

### Chord symbols and dynamics

Both go in through the commands their popovers run, with a note selected where they should go
([chord-symbols.lua](../examples/recipes/chord-symbols.lua)):

```
NoteInput.StartChordSymbolInput
NoteInput.AcceptCurrentChordSymbolTextInput?Definition=G7&ChordSymbolEntryAdvanceType=kEndInput
NoteInput.CreateDynamic?Definition=mf
```

The accept command alone makes nothing. Chord symbols made this way don't join a run's one undo step: each takes
three presses of Edit > Undo. `NoteInput.CreatePlayingTechnique?Definition=pizz.` made nothing.

Never use `NoteInput.CreateText`. It opens Dorico's text editor at the selection and waits for typing, and while
it's open Dorico runs no scripts at all. Escape doesn't close it; clicking empty paper does. Use `stream:createText`.

### Flows

- `Project.Flow.New` adds a flow at the end, holding every player. It doesn't say which flow it made, so look for
  the id that wasn't there before ([14-add-notes-rests-text.lua](../examples/fundamentals/14-add-notes-rests-text.lua)).
- `Project.Flow.Rename?FlowID=<id>&Name=<name>` renames it.
- `Project.Flows.MoveToStart?FlowIDArray=<id>`: a single id is the whole array.
- `flow:removePlayer(player)` takes a player out of one flow.
- An empty flow prints "Tacet" in every part, since each part layout includes every flow. `layout:removeFlow(flow)`
  on each part layout prevents it.
- `stream:deleteEventsInRange(RL(0), RL(<end>))` on each of `flow.allStreams` clears a flow's notes, texts, time
  signatures and breaks, and keeps its players and its place.
- Deleting a flow needs Setup mode: `Window.SwitchMode?WindowMode=kSetupMode`, then `Project.Flows.Delete`. Dorico
  asks the user to confirm, and the command waits for the answer.

### Players

- `score:addPlayer("instrument.strings.violin", false, 1)` adds a player and returns it
  ([16-flows-and-players.lua](../examples/fundamentals/16-flows-and-players.lua)). The instrument ids are the
  `entityID` values in `instruments.xml` in Dorico's program folder; pass only ids listed there. The player joins
  every flow, and Dorico makes a part layout for it.
- Finding a player's id: rename a candidate id to a unique token with `Project.Player.Rename?PlayerID=<id>&Name=<token>`,
  see which player's `tostring` becomes the token, then give it its name back. Try the player's first instrument's
  id first; a search through other ids renames every player it passes, and undoing a rename can bring a transposing
  player's name back spelt differently (`Trumpet Zoë (B Flat)` for `Trumpet Zoë (B{@flat@})`).
- Staff labels show instrument names, so renaming a player doesn't change them, and instrument names can only be
  set in Dorico's Edit Instrument Names dialog.
- A script can't delete a player. There's no `removePlayer` on the score, and `Project.Players.Delete` acts on the
  Setup-mode selection, which commands can't set. `Project.Players.DeleteEmpty` opens Dorico's "Delete Empty
  Players" dialog for the user to confirm.
- `Project.Layouts.Delete?LayoutIDArray=<id>` deletes a part layout silently.

### Layout and notation options

Options are set by command, in the form Dorico logs for the Remote Control API's `setoptions`
([15-layout-and-notation-options.lua](../examples/fundamentals/15-layout-and-notation-options.lua)):

```
Project.Layout.SetOptions?Dictionary=list: {string: "flowHeadingBehaviour"}\, {string: "kNoFlowHeadings"}&OpenScoreID=<score.openScoreID>&LayoutIDArray=<layout id>
Project.Flow.SetNotationOptions?Dictionary=list: {string: "barlineOptions.finalBarlineType"}\, {string: "kDouble"}&OpenScoreID=<id>&FlowIDArray=<flow id>
```

- The dictionary alternates path and value items, separated by an escaped comma (`\, `). Inside an item, a
  backslash, a quote and a comma each need a backslash of their own. Passing the whole list through the `commands`
  helper gives commas and backslashes theirs. It can't give a quote one, since it would escape that backslash too.
- Only single ids have been tried in list parameters such as `FlowIDArray`. Passed several, as `1,2`, the helper
  would escape the commas between them.
- Always give a flow's id in `FlowIDArray`. The Remote API's `setoptions` with `flowIDs` changed flow 0 instead.
- Option paths and values are the names `getoptions` reports, such as `flowHeadingBehaviour` (`kNoFlowHeadings`,
  `kAddHeadingsAfterFirstFlow`, `kAlwaysInsertHeadings`), `flowBreakBehaviour` (`kStartNewPageForFlows`,
  `kNoFlowBreaks`), `hideEmptyStavesPolicy`, `alwaysVisiblePlayers`, and per flow `barlineOptions.finalBarlineType`
  and `barlineOptions.defaultBarlineType` (`kNormal`, `kDouble`, `kFinal`, `kNone`).
- Lua can't read any option back. Overwriting one loses the user's value unless you can recover it another way
  (section 4), so say which options a script changes.

### Layout tricks that worked

- A system break needs a barline, and a new flow has none. Select a note, run
  `NoteInput.CreateTimeSignature?Definition=X` (an open meter at that note), hide it with `kTimeSignatureHide`, then
  run `Edit.CreateSystemBreak` with the note still selected. `createSystemBreak` from Lua makes a break that
  doesn't take effect.
- To remove rests, select a voice's first event, `Edit.SelectAtEndOfFlow`, then `Edit.RemoveRests`. An empty staff
  has no event to select, so put an invisible note in it first.
- To show only some staves on a system, set `hideEmptyStavesPolicy = kAllSystems` with every player who must always
  show in `alwaysVisiblePlayers`.

### Things that didn't work

- `copyRange` copies nothing, within a flow or across flows.
- There's no silent MusicXML export: `File.Export` and `File.Export.SpecificFlowsAndParts` open dialogs.
- A saved project is binary inside (`score.dtn`), so reading the project file isn't an option.

## 6. Commands

- The syntax is `Name?key=value&key=value`.
- Dorico reads a backslash in a value as an escape, and a bare `&` or `,` ends the value: `Name=A, B` names a
  player `A`. Write `\&` for an ampersand, `\,` for a comma and `\\` for a backslash. `=` and any other character,
  accented letters included, go through as they are. Build every command with one function that does this, as the
  `commands` helper does ([10-commands.lua](../examples/fundamentals/10-commands.lua)), so a name like
  "Violin, solo & tutti" arrives whole.
- `doCommand` returns nothing, for a command that worked and for one Dorico has never heard of alike. Check what you
  send: `tostring` turns a missing value into the word `nil`, and a wrong id selects, renames or deletes the wrong
  thing, or nothing, with no error.
- Most commands act on the selection, as their key commands do.
- A command that opens one of Dorico's dialogs waits until the user answers it, and the script waits with it.

## 7. Undo, redo and saving

The handbells plug-in's guide says that edits made through the object model never enter the undo history. On
Dorico 6.2.30 they do ([spikes.md](spikes.md#undo)). This is what was seen;
[18-undo.lua](../examples/fundamentals/18-undo.lua) shows the second point.

- Everything a script run changes is one undo step, whether by command or through the object model (`createNote`,
  `createText`, `stream:delete`, `propertyTable:set`). Edit > Undo afterwards takes the whole run back. Options set
  by command go with the rest. Chord symbols made with the popover's commands are the exception found so far: they
  make undo steps of their own, three to a chord symbol.
- `Edit.Undo` inside a script takes back everything that run has done so far, object-model edits included, and
  nothing from before the run.
- Only the first undo is safe. After an undo inside a run, whatever the run changes next joins the user's previous
  undo step, so Edit > Undo afterwards takes back both, and a second `Edit.Undo` in the run takes back the user's
  last edit at once.
- A run that changes something and puts it back (a marker text made and deleted) still leaves an undo step, which
  Edit > Undo uses up without changing anything visible. Say so in the script's notes, or users will think their
  first undo did nothing.

What a script should do with that:

1. If it must read through a temporary copy (section 3), do all of that first and take it away with exactly one
   `Edit.Undo`, before changing anything, and change nothing after it unless a joined undo step is acceptable.
2. Prefer routes with no undo at all, such as moving the selection an octave and back (section 3).
3. For a big change, save first (`File.Save`), so that File > Revert takes the run back cleanly.

Saving:

- `File.Save` on a saved project is silent and immediate. On a never-saved one it opens Save As, so check the text
  export's `Path` first and ask the user to save.
- To confirm a save happened, compare the file's modification time before and after (`lfs.attributes(path,
  "modification")`).
- After a run whose own undo took everything back, Edit > Redo brings it back. Warn users who might press it.

Reading options back through the Remote API straight after an undo can catch Dorico before it has finished: an
option still shows its new value, or a reply leaves an option out. Read again a moment later.

## 8. Asking the user

Lua in Dorico has no windows, but it can start a program and wait for it
([17-ask-and-report.lua](../examples/fundamentals/17-ask-and-report.lua)). The script writes a small script for the
other program, runs it with `os.execute` (on a Mac, `io.popen` to read its output), and reads the answer back from
a file. Dorico waits, frozen, while the box is open.

```lua
local ok, how, code = os.execute(command)   -- Lua 5.2: true|nil, "exit"|"signal", code
```

- Ask before changing anything, so that Cancel leaves nothing to undo.
- Treat any failure as a cancel: no answer file, an empty answer, a program that didn't start.
- If several runs could leave answer files, give each run an id that the box writes back, and ignore an answer
  without it.

### Windows: PowerShell and Windows Forms

```
powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "<box.ps1>" -Out "<answer.txt>"
```

- Nothing to install: Windows PowerShell 5.1 and Windows Forms are on every Windows 10 and 11 machine. Startup takes
  a few seconds.
- `-WindowStyle Hidden` stops a console window flashing up, and `TopMost` puts the form in front of Dorico.
- Begin the command with `powershell`, not a quoted path. `os.execute` goes through `cmd.exe`, which strips the
  first and last quotes from a line that starts with one.
- Write the answer as UTF-8 without a byte-order mark: `[System.IO.File]::WriteAllText(path, text, (New-Object
  System.Text.UTF8Encoding $false))`.

PowerShell traps the handbells plug-in fell into, for bigger dialogs:

- Call `SetProcessDPIAware()` and scale fixed sizes, or the dialog is blurry on a high-DPI screen.
- Set `UseMnemonic = $false` on labels, or "P&F" shows as "PF".
- `ConvertFrom-Json` hands back a one-item list as a bare value. Normalise every list.
- `-eq`, `-contains` and property lookups ignore case, and so do variable names: `$button` is the parameter
  `$Button`.
- `$null` passed to a .NET `string` parameter arrives as `""`. Use `[NullString]::Value`.

### Mac: osascript

A one-line AppleScript `display dialog` with `default answer` asks for a word, and `io.popen` reads what
`osascript` prints. Cancel makes `osascript` fail with no output. This is written from Apple's documentation and
hasn't been run on a Mac. For a full dialog, the handbells plug-in has a JavaScript for Automation (JXA) window,
also not yet run on a Mac.

## 9. Running a script from a key

- With no setup: run a script once with Script > Run Script, and Ctrl+Shift+Alt+R (Script > Run Last Script) runs
  it again ([19-key-command.lua](../examples/fundamentals/19-key-command.lua)). A global keeps state between
  presses, as [hotkey-colour-cycle.lua](../examples/recipes/hotkey-colour-cycle.lua) does to step through colours.
- A key of its own: the user's key commands are in `keycommands_en.json` (one file per language) in
  `%APPDATA%\Steinberg\Dorico 6`, which appears once any key command has been changed. An entry in the `kGlobal`
  context's `shortcuts` list binds a key to a script:
  `{ "Script.RunScript?ScriptPath=C:/path/to/script.lua&ShowConsole=false": [ "Ctrl+Alt+K" ] }`. Dorico's own
  `keycommands_en.json` in its program folder shows the layout, including commands bound with parameters. This needs
  Dorico closed while the file is edited, and it wasn't run here. ConsoleTools sets its keys up this way.

## 10. Working through other projects

A script can open, change, save and close other projects. `File.Open?File=<path>` makes the opened project
`app.currentScore` straight away; after the work, `File.Save` and `File.CloseProject?OpenScoreID=<id>&Save=false`,
and the project the script started in is current again. A batch script working on someone's files should check
each path is inside the folder it was given before touching anything ([spikes.md](spikes.md), S5).

## 11. Testing from outside Dorico

### The Remote Control API

With Remote Control enabled in Dorico's preferences, a WebSocket at `ws://127.0.0.1:4560` takes JSON messages:

- `connect` with a client name and `handshakeVersion: "1.0"`. The first time, Dorico asks the user to allow the
  client and replies with a session token: answer with `acceptsessiontoken`, and keep the token for next time.
- `command` with a command string, `getstatus`, `getcommands`, `getflows`, `getoptions` and `setoptions`.
- Status messages are partial. Each is a delta to merge into what you have, and Dorico pushes them unasked.
- Some commands that work from Lua are refused from the Remote API (a player rename came back `kError`).

`tools/dws.py` is a client using only the Python standard library.

### Running a script and getting results back

- `Script.RunScript?ScriptPath=<path>&ShowConsole=false` runs a Lua script. Scripts queue up behind each other.
- The script reports through a file: `spikes/lib/probe.lua` writes `result.json` (checks, facts, any error), and
  the driver waits for it.
- Run through a launcher. A script Dorico reaches late, after the driver gave up waiting, must not read the next
  run's arguments, so `tools/run_lua.py` writes a small Lua file for each run that names that run's arguments and
  runs the real script. A rerun through `Script.RunLastScript` runs the same launcher again. Sent through the
  Remote API, that command returns before the rerun happens, so wait for the rerun's result: a rerun Dorico
  hasn't reached yet can run nested inside the next script's commands.
- Check syntax with `luac -p` before sending anything.

### Never touch the user's work

- Run tests only on scratch copies: copy the project to a scratch folder, open the copy, and close it unsaved.
- Confirm the active project is the copy inside the script, before changing anything: compare the text export's
  `Path` with the copy's path, and refuse if they differ.
- Wait for a newly opened project to settle: its id shows in the status before Dorico has finished with it.
- A script that waits on a box blocks every later script and command. If a test leaves one open, close it before
  anything else will run.

### Driving dialogs

- UI Automation can wait minutes on a busy Dorico. Find windows with Win32 instead (`FindWindow`, `EnumWindows`),
  which reads titles without asking the program.
- UI Automation sees Windows Forms controls as bare panes. Press their buttons with `BM_CLICK`
  (`tools/click.ps1`) and fill their text boxes with `WM_SETTEXT` (`tools/fill.ps1`).

### Unit tests without Dorico

Keep pure logic (parsers, chord naming, ranges) in code that doesn't name `DoApp` or `DoCore`, and test it with
stock Lua 5.2. The examples' helper blocks are tested this way: `tests/lib/helpers.lua` loads a block out of an
example by its `-- helper:` markers, and `tests/test_helpers.lua` tests it.

## 12. Gotchas, in one list

- One Lua state for the session: keep everything local, clear your modules, guard `package.path`.
- Syntax errors are skipped silently. Runtime errors end the script.
- `Script.ShowConsole` toggles the console.
- `stream.events` raises an error on most real music. `stream:dump()` always works but has no properties.
- Every pitch is sounding, and nothing says how an instrument transposes.
- Time and key signatures can't be read. Bar numbers come from the text export.
- Players have no id and no `==`. Player ids aren't instrument ids.
- `flow.instruments[i].id` owns `flow.voiceStreams[i]`; `flow.instruments[i].streams` is broken.
- `RhythmicLength(0.5)` is 0. Fractions go in as `RhythmicLength(n, d)`.
- `MIDIPitchWithSpelling.fromString` can crash Dorico on bad input.
- `EventEdit.Select` needs the event's block id from `stream.blockInstances`, and replaces the selection.
- `doCommand` returns nothing and reports nothing. Command values escape `\`, `&` and `,`.
- `NoteInput.CreateText` blocks Dorico until someone clicks the page.
- A colour set by command can't be read back, and a property-table read can lag the page.
- `kEventHide` hides neither texts nor rests. Naturals hide only by command.
- Layout options can be set, never read. `setoptions` with `flowIDs` changes flow 0.
- A script can't delete a player. `Project.Flow.New` adds every player to the new flow.
- Every edit a run makes, object-model edits included, is one undo step. Only the first `Edit.Undo` in a run is
  safe. Chord symbols by popover make three undo steps each.
- `os.execute` freezes Dorico until it returns.
- The text export may have no flow numbers and no hidden texts.

## 13. Which example shows what

| Technique | Example |
| --------- | ------- |
| The no-project guard, print, one Lua state | [01-hello.lua](../examples/fundamentals/01-hello.lua) |
| Players, flows, which player owns a voice | [02-walk-the-score.lua](../examples/fundamentals/02-walk-the-score.lua) |
| Reading notes from the dump | [03-read-notes.lua](../examples/fundamentals/03-read-notes.lua) |
| Noteheads and colours through a pasted copy | [04-noteheads-and-colours.lua](../examples/fundamentals/04-noteheads-and-colours.lua) |
| The text export: titles, path, instrument names | [05-names-from-the-text-export.lua](../examples/fundamentals/05-names-from-the-text-export.lua) |
| Building and escaping commands | [10-commands.lua](../examples/fundamentals/10-commands.lua) |
| Finding the selection, acting on it | [11-act-on-the-selection.lua](../examples/fundamentals/11-act-on-the-selection.lua) |
| Selecting by id, colouring by command | [12-select-by-id.lua](../examples/fundamentals/12-select-by-id.lua) |
| Writing notes, rests and text | [14-add-notes-rests-text.lua](../examples/fundamentals/14-add-notes-rests-text.lua) |
| Layout and notation options | [15-layout-and-notation-options.lua](../examples/fundamentals/15-layout-and-notation-options.lua) |
| Adding flows and players, player ids | [16-flows-and-players.lua](../examples/fundamentals/16-flows-and-players.lua) |
| A box asking the user | [17-ask-and-report.lua](../examples/fundamentals/17-ask-and-report.lua) |
| What undo does | [18-undo.lua](../examples/fundamentals/18-undo.lua) |
| A script for a key, state between runs | [19-key-command.lua](../examples/fundamentals/19-key-command.lua) |
| Colouring every note | [colour-by-pitch.lua](../examples/recipes/colour-by-pitch.lua) |
| Labels at each note | [label-notes.lua](../examples/recipes/label-notes.lua) |
| Ranges, parallels, bar numbers from the export | [proofread.lua](../examples/recipes/proofread.lua) |
| Naming chords, chord symbols by command | [chord-symbols.lua](../examples/recipes/chord-symbols.lua) |
| A report on players and instruments | [instrument-report.lua](../examples/recipes/instrument-report.lua) |
| A key that cycles colours | [hotkey-colour-cycle.lua](../examples/recipes/hotkey-colour-cycle.lua) |
| A complete plug-in with a dialog and tests | [Handbells Used Chart](https://github.com/ThePrismSystem/handbells-used-chart-dorico) |
