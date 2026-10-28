# What the spikes found

Each spike asked one question about Dorico 6's Lua scripting that the examples needed answered. The probes are in
`spikes/`, run on scratch copies with `python tools/run_lua.py spikes/<probe>.lua --open fixtures/sample.dorico`.
Everything here was seen on Dorico 6.2.30 (build 6245) on Windows 11.

## The sample project's import

`fixtures/build_sample.py` makes the sample by importing MusicXML, and these details of the sample come from the
import:

- A tied pair comes in as one note: the flute's C5 tied over the barline is one event lasting three beats.
- Rests come in as implicit rests, which aren't events: no voice stream holds a `kRestEvent`.
- A transposing instrument's player name gains its transposition. A part named "Trumpet Zoë" becomes the player
  `Trumpet Zoë (B{@flat@})`, and `tostring(player)` gives that text, token and all. A part named "Trumpet in B♭"
  became `Trumpet♭ (B)`.
- A MusicXML part's key is its written key, so a B♭ trumpet in a C major piece is written in D major.

## The text export

Probe: `export_names.lua`, which puts a marker text in every voice stream, exports, and deletes the markers.

- The `ID` column is `<flow>-<stream>-<event>`, counting flows from 0. `FlowNumber` counts them from 1.
- A marker's row names its instrument in the `Instrument` column, without the transposition Dorico adds to the
  player's name: the trumpet's rows say `Trumpet Zoë`, where `tostring(player)` gives `Trumpet Zoë (B{@flat@})`.
  `Violin, solo & tutti` comes through whole, in quotes.
- The `Project Info (Title)` row holds the project's title, and a `Flow Info (Title)` row each flow's, with its
  `FlowNumber`.
- Lyrics and dynamics have rows of their own, each naming its instrument.

## Commands, selections and lengths

Probe: `select_and_lengths.lua`.

- `app:doCommand` returns nil, for a command that worked and for one Dorico doesn't know (`No.Such.Command`)
  alike. A script learns whether a command did anything only by reading the project afterwards.
- A second `EventEdit.Select` replaces the selection. With two violin notes selected by id one after the other, the
  S1 trick found only the second. To select a run of notes, select the first and add the rest with
  `EventEdit.NavigateRightExtend`.
- `DoCore.RhythmicLength(n)` keeps only the whole part of n: a text made at `RhythmicLength(0.5)` sits at 0.
  `RhythmicLength(n, d)` is n/d quarter notes, so `(3, 2)` put a text at 1.5 and `(7, 3)` at 7/3.

## Command values

Probe: `rename_escapes.lua`, renaming a player and a flow to each candidate and reading the names back.

- A bare comma ends a value: `Name=A, B` names the player `A`. The sample's `Violin, solo & tutti` became `Violin`
  this way. `\,` is a literal comma, as `\&` is an ampersand and `\\` a backslash, so `A\, B \& C` gives
  `A, B & C`. Quotes are kept as part of the name. A semicolon needs nothing.
- Undoing a rename can bring a transposing player's name back spelt differently. Renamed and then undone, `Trumpet
  Zoë (B{@flat@})` came back as `Trumpet Zoë (B Flat)`.

## Players, layouts and options

Probes: `players_and_options.lua` with its driver `players_and_options.py`, and `options_undo.py`.

- The ids Lua gives layouts and flows are the ids the Remote API's `getoptions` takes. In the sample, layout 0 is the
  full score (it holds every player) and layouts 1 to 4 are the parts. Flows are 0 and 1.
- In the sample each player's id is its first instrument's id, so `Project.Player.Rename?PlayerID=4` renamed the
  player whose first instrument is 4, the one just added.
- `score:addPlayer("instrument.strings.violin", false, 1)` returned a player named `Violin` and made a part layout
  for it. The instrument ids are the `entityID` values in `instruments.xml` in Dorico's program folder.
- After a run that added a player, renamed players, took the new player out of a flow and added a flow, one
  Edit > Undo took all of it back.
- Options are in the run's undo step too. After fundamental 10 set a layout option and a notation option, one
  Edit > Undo took both back in five runs out of five, with both read back 0.3 seconds after the undo. Read through
  the Remote API straight after the undo, the layout option can still show the new value, or a reply can leave an
  option out, because Dorico is still applying the undo. Earlier runs that read at once had read too early, which
  made the layout option seem to need a second undo.

## S3: what the dump says

Probes: `s3_dump_details.lua`, `s3_gap.lua`, `s3_element_tables.lua`.

- Each flow has a timebase stream, a stave stream per staff, a player stream per player (empty in the
  sample) and a voice stream per voice.
- Voice streams hold notes, grace notes, slurs (`kSlurEvent`, with a duration) and lyrics (`kLyricEvent`).
  Positions and durations are in quarter notes from the start of the flow.
- Stave streams hold clefs (`kClefEvent`, with a line naming the clef, such as `clef.treble`) and dynamics
  (`kDynamicGroupEvent`).
- The timebase stream holds a `kBarDivisionEvent` for each time signature and a `kTonalityDivisionEvent` for
  each key signature. Each names only an element id.
- Ties aren't events: a tied note is one note with the whole length.
- A tuplet is a `kTupletEvent` in the voice stream (`kTupletEvent (id:16) at 0, duration 1  3:2, unit = e`), and its
  notes carry their real lengths: a triplet of eighths reads `duration 1/3` at positions 0, 1/3 and 2/3, not the
  eighth they're written as. Probe: `tuplet_and_unison.lua`, opening `tuplet.musicxml`.
- Implicit rests aren't listed. Rests the music has as events (from note input, or `createRest`) are.
- Removed rests leave no trace. After `Edit.RemoveRests` on the trumpet's bar 5, the page shows the gap, but
  every stream's dump is the same as before. A script can't tell a bar with removed rests from one with implicit
  rests, so the proofreading recipe has no incomplete-bar check.
- `flow.elementTables` has `barDivisions`, `dynamics` and `tonalityDivisions`:
  - Dynamics can be read. Each dynamic's sub-element has `kDynamicImmediateChangeBasicType` (0 for the sample's
    mf, 1 for its p) and `kDynamicImmediateChangeIsMezzo` (true, false). The intensity itself fails with "Invalid
    conversion".
  - Time signatures can't, so a script has no way to read the meter. A bar division element has properties such as
    `kBarDivisionIrregularBarLength`, but `kBarDivisionTimeSignatures` fails with "Invalid conversion".
  - Key signatures can't: reading `tonalityDivisions` raises "Trying to use unregistered class".

## S6: where print goes

Probe: `s6_print.lua`, driven by `s6_print.py`.

`print` writes to Dorico's Script Console (Script > Show Script Console). Lines printed while the console is
closed are kept and appear when it opens. `io.write` output appears nowhere. A script can open the console itself
with `app:doCommand("Script.ShowConsole")`. The console opens with "Always on top" ticked.

`Script.ShowConsole` toggles the console (`s6_console_toggle.py`: open, closed, open, closed), so a script that
opened it on every run would close it on every second run. The examples report with `print` and leave the console
alone, and their headers say to open it.

## S8: reading and setting note properties

Probes: `s8_properties.lua`, `s8_colour_read.lua`.

- A note's property table lists only the properties it has: `kEventPosition`, `kEventDuration`, `kNotePitch`
  (the MIDI number) and a few more, until something sets another.
- Setting a colour by command works on the selected notes: `UI.InvokePropertyChangeValue?Type=kEventColour&Value=`
  followed by `#ffff0000`, `string: "#ffff0000"` or `string: "#0000ff"`. All three coloured their note. The change
  is a command, so Edit > Undo takes it back.
- Setting a colour through the property table works too, on an event object from `stream.events`:
  `propertyTable:set("kEventColour", DoCore.Variant.createString("#ff8000ff"), ctx)`. Edit > Undo takes it back
  like any other edit (see Undo, below). It needs the event object, which a stream holding lyrics or slurs can't
  give.
- A colour set by command can't be read back. The property is listed, but its Variant has `type` -1 and `valid`
  false, and `tostring` gives "". A colour set from Lua reads back as the string it was set to, and still does after
  the project is saved and reopened and in a pasted copy (fundamental 04 reads the sample's). So a script can tell
  that a note has a colour, but not which one, unless a script set it.
- A property-table read can lag the page. The sample's first trumpet note has a colour set through its property
  table. After the colour-by-pitch recipe coloured it by command, the page showed the new colour, but Lua still
  read the old one.
- `UI.InvokePropertyChangeValue?Type=kNoteheadSetOverride&Value=string: "noteheadset.diamondNoteheads"` changed
  nothing.

## S1: reading the selection

Probes: `s1_read_selection.lua`, driven by `s1_selection.py`; `select_note.lua` makes the selections.

Lua has no selection API, but a script can find out which notes are selected:

1. Dump every voice stream.
2. Run `NoteEdit.PitchUpChromatic`, which moves only the selected notes up a semitone.
3. Dump again. The notes whose spelling changed are the selection.
4. Run `Edit.Undo` once. Inside a script it takes back everything that run has done, so the music is as it was.

With one violin note selected it found that note, and with a second added (`EventEdit.NavigateRightExtend`) it found
both. With nothing selected it found nothing. Each time, every stream's dump afterwards was identical to before.

The trick uses the run's one `Edit.Undo`, and a second would take back the user's own last edit. It finds notes and
grace notes but no other items, it misses a note that can't go a semitone higher, and Edit > Redo afterwards would
put the semitone back. The Remote API's status (`hasSelection`, `selectedEventType`: `kNoteEvent`, `kMixed`,
`kNone`) says what kind of thing is selected, but only to a program outside Dorico.

A later probe (`pitch_up_down.lua`) found a route with no undo. `NoteEdit.PitchUpOctave` then
`NoteEdit.PitchDownOctave` gave every note back its exact spelling, Fb4, E#4, Ebb4 and Dx4 included, where a semitone
up and down respelled them (G#4 came back as Ab4, E#4 as F4). Fundamental 07 uses the octave route, so the run has
no undo and its later edits stay in its own undo step. Moving a chord's C4 up an octave onto the chord's own C5 left
two C5s, not one merged note, and moving it back down restored both (`tuplet_and_unison.lua`).

## S4: creating items

Probes: `s4_create.lua` (commands sent from Lua), `s4_record.py` (Dorico's popovers, typed into the scratch window,
with `application.log` read for the commands they ran).

Each was tried with one piano note selected by id:

- Chord symbols: `NoteInput.StartChordSymbolInput`, then
  `NoteInput.AcceptCurrentChordSymbolTextInput?Definition=C7&ChordSymbolEntryAdvanceType=kEndInput`. This is what
  the chord symbol popover runs. It makes a `kChordSymbolEvent` in the timebase stream, and the dump names it
  (`kChordSymbolEvent (id:326) at 0  C  0`). The accept command alone makes nothing. Later, the chord-symbols
  recipe's dump named its chords in full (`Am`, `G7`). These commands don't join a run's one undo step:
  `chord_undo.py` found three undo steps for each chord symbol, so the recipe's four took eleven presses of
  Edit > Undo.
- Dynamics: `NoteInput.CreateDynamic?Definition=mf` makes a `kDynamicGroupEvent` in the stave stream.
  `Dynamic=ff` makes nothing.
- Staff text: never by command. `NoteInput.CreateText` opens Dorico's text editor at the note and waits for
  typing, and while it is open Dorico runs no scripts at all. Escape sent with an Alt press (to bring the window
  forward) only toggles the menu bar; clicking empty paper closes the editor. Use `stream:createText(position,
  duration, text)` instead, which the handbells plug-in has used throughout.
- `NoteInput.CreatePlayingTechnique?Definition=pizz.` made nothing.
- Dorico also has `Edit.GenerateChordSymbolsFromSelection`, its own chord detection, not tried here.

## Undo

Probe: `undo_object_edits.py`, driving `undo_object_edits.lua` on seven fresh copies. The handbells plug-in's guide
says object-model edits never enter the undo history, but on Dorico 6.2.30 they do:

- A run that only made a text (`createText`) was taken back by one Edit > Undo afterwards. So was a colour set with
  `propertyTable:set`.
- A run that made a text, ran `Project.Flow.New` and made another text was taken back whole by one Edit > Undo
  afterwards, and an `Edit.Undo` inside such a run took back all three edits, the text made before the command
  included.
- After an `Edit.Undo` inside a run, a text the run made next joined the user's previous undo step: one Edit > Undo
  afterwards took back that text and the user's own earlier rename together.
- A run that made a text and deleted it again still left an undo step. Edit > Undo afterwards used it up and left the
  user's earlier edit in place.

The examples follow the rule that everything a run changes is one undo step, that an undo inside a run takes back
everything the run has done, and that a run changes nothing after its one undo.

## S2: running a script from a key command

Probe: `s2_counter.lua`, rerun through the Remote API.

- Run Last Script needs no setup. Dorico binds `Script.RunLastScript` to Ctrl+Shift+Alt+R by default. Run a
  script once with Script > Run Script, and from then on the key runs it again. The probe counted its own runs
  in a global variable: three runs (one from the runner, two through `Script.RunLastScript`) gave 1, 2 and 3, so
  state also survives between runs.
- Sent through the Remote API, `Script.RunLastScript` returns before the rerun. The hotkey recipe's test sent
  it twice and went straight on, and a rerun Dorico hadn't reached yet ran nested inside the next script's
  commands, one launcher inside another. Waiting for each rerun's result before the next step fixed it.
- A key of its own for one script goes in the user's key-command file, `keycommands_en.json` in
  `%APPDATA%\Steinberg\Dorico 6` (one per language; there is none until the user changes a key command). Dorico's own
  `C:\Program Files\Steinberg\Dorico6\keycommands_en.json` shows the shape, and that commands with parameters can
  be bound (`"File.Open?FilterID=MusicXMLImportFilter": [ "Ctrl+Shift+O" ]`). An entry in the `kGlobal` context's
  `shortcuts` list would be
  `{ "Script.RunScript?ScriptPath=C:/path/to/script.lua&ShowConsole=false": [ "Ctrl+Alt+K" ] }`.
  ConsoleTools sets its keys up this way. It wasn't run here: it means editing the user's key-command file and
  restarting Dorico, which this repository's tests never do.

## S5: working through other projects

Probe: `s5_batch.lua`, on two copies in the run folder; `flow_titles.lua` read one back.

A script can open, change, save and close other projects. `File.Open?File=<path>` from inside a script makes the
opened project `app.currentScore` straight away. The probe renamed each copy's first flow, ran `File.Save` and
`File.CloseProject?OpenScoreID=<id>&Save=false`, and the project it started in was current again afterwards. Read
back, the copy's first flow was titled "Batched". The probe refused any path outside the run folder, as a batch
script working on someone's own files should check its folder before touching anything.

`DoCore.ScriptHost`'s names (`currentScore`, `save`, `showFolderChooser`) aren't static members of the class, and
nothing here called them.

## S7: plug-in folders with Info.lua

Not run. DoricoUse found, in Dorico's binary, a second kind of script plug-in: a folder in Script Plug-ins holding
an `Info.lua` that returns a table whose `MenuCommands` entries have a `name` and a `handler`. Like a single `.lua`
file in that folder, it appears in the Script menu only after Dorico restarts, and this repository's tests never
restart Dorico. The examples are single files.
