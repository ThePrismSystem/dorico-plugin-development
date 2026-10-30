# What the spikes found

Each spike asked one question about Dorico 6's Lua scripting that the examples needed answered. The probes are in
`spikes/`, run on scratch copies with `python tools/run_lua.py spikes/<probe>.lua --open fixtures/6.2.30/sample.dorico`.
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
- Two undos in one run take back the user's own edit at the second. Fundamental 13 run twice in one script run
  (a test tried it) undid an earlier rename of the second flow.
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
an `Info.lua` that returns a table whose `MenuCommands` entries have a `name` and a `handler`. Whether Dorico picks
up a new plug-in of either kind without a restart wasn't checked: that would mean adding files to the user's own
Script Plug-ins folder, and if it needed a restart, trying the plug-in would too, which this repository's tests never
do. The examples are single files, run with Script > Run Script.

## F1: what a saved score holds

Probes: `f1_catalogue.lua` and `f1_changes.lua`, both run on stock Lua outside Dorico over 52 projects: the
fixtures, copies of the 7 example projects Dorico installs, and the 39 projects at
<https://ancientgroove.co.uk/dorico/index.html>. Between them they were saved by every Dorico from 6.0.22 to 6.2.30.

- Every project decoded, the 7 installed examples from `score.xml` and the rest from `score.dtn`. The biggest, an
  installed example with 695,427 nodes, took 4.4 s in stock Lua, most of it unzipping.
- The catalogue lists every node path with its values. It found 46 kinds of event definition, from
  `NoteEventDefinition` (533,846 of them) to a single `MultiRestEventDefinition`. None of the projects has a chord
  symbol or a tab staff. [file-format.md](file-format.md) describes the tree it found.
- `fileVersion` changed with every release, patch releases included: 1.1392 from 6.0.22, 1.1416 from 6.1.0, 1.1417
  from 6.1.10, 1.1444 from 6.2.0, 1.1450 from 6.2.20 and 1.1452 from 6.2.30. The installed examples say 6.1.5 and
  1.1412.
- `f1_changes.lua` looks for paths that every parent node has in some versions and none has in others. Across all 52
  projects, every such path was an option (about 80 engraving, playback, notation and view options, such as
  `repeatNotationOptions` from 6.2.0 on) or a library field, and each was an addition. Events, element tables,
  players, layouts and project info kept the same paths in every version. Run on only a few projects, the probe also
  reports content that some projects happen not to have, such as dynamics.

## F7: XML and binary

The installed example projects hold `score.xml` and `scorelibrary.xml`; every other project found holds `.dtn` files,
including the 8 guided-tutorial projects in Dorico's program folder. Neither Dorico's `preferences.xml` nor its 1,090
commands has anything that saves XML. Dorico 6.2.30 opens the XML projects, and the reader reads them into the same
tree: for one installed example, `scorereader.xml` gave 238,312 nodes and Python's XML parser counted 238,312
elements.

## F2 to F6: what the events hold, and how they match Lua

Probes: `tree_dump.lua` (stock Lua: writes any project's tree as text), `f2_events.lua` (in Dorico: every stream's
dump with its owners, the players and the layouts) and `f2_compare.lua` (stock Lua: sets `f2_events.lua`'s result
beside the decoded file). Run on `fixtures/6.2.30/reading.dorico`, whose source says what each item is, and on Fauré's
*Dolly* from `fixtures/6.2.20`.

- Stream ids, event ids and instrument ids in the file are the ones Lua gives. For both projects, every event in every
  stream's dump matched a decoded event by id and position, and every decoded event was in a dump: 0 mismatches over
  22 streams in the fixture and over 8,794 notes, 933 slurs, 288 dynamics, 200 breaks and the rest in *Dolly*.
- *Dolly* was saved by 6.2.20. Opening it in 6.2.30 kept every id, so a reader can match Lua's view of an upgraded
  project to the file the user opened. Dorico shows a notice ("This project was created in version 6.2.20 of Dorico.
  It will be automatically updated to the current version.") with only an OK button; `tools/run_lua.py` now clicks it.
- Where events live: the timebase stream holds time and key signatures, tempos, chord symbols and rehearsal marks; a
  staff's stream holds its clefs, dynamics and any text imported from MusicXML; a voice stream holds notes, tuplets,
  lyrics, slurs, playing techniques and the text `createText` makes.
- What the file adds to the dump: lyric text and syllable types, dynamic names, time and key signatures, chord symbol
  roots and qualities (the dump names chords too), text styles and fragments, articulations, string numbers, and
  every property with its context. [file-format.md](file-format.md) has the details.
- Contexts (F3): a value set through Lua's property table or by `EventEdit.ChangeProperty` has no context;
  `Edit.SetNoteheadSetOverride` stores layout -1 with the note's block instance; the Properties panel with a part on
  screen stores that part's layout; `Edit.ShowAccidentalInBrackets` stores layout 0.
- Ownership (F4): each flow's `flowPlayers` lists every player's instruments and their stave and voice streams, the same
  ownership as `flow.instruments`. Instruments' transpositions and ranges are in their library definitions.
- Options (F5): every flow carries a full set of notation options, including the accidental duration rule and every
  cautionary-accidental setting; layouts carry their layout options.
- Definitions (F6): every library definition has an `entityID` and a `name`, so one pass over the library turns the ids
  events use into names.

The reading fixture also showed what Dorico 6.2.30's MusicXML import does with text: every `<words>` direction lands
above the staff whatever its `placement`, a direction with two `<words>` keeps only the last, and `font-weight` is
dropped. `pizz.` and `arco` arrive as playing techniques, not text.

## W1 to W7: changing what the reader found

Probes: `w1_text_rebuild.lua`, `w2_lyrics.lua`, `w3_chord_replace.lua`, `w4_bulk_text.lua`, `w5_accidentals.lua` with
`w5_undo.py`, and `w7_selected_text.lua`, each on a scratch copy of `fixtures/6.2.30/reading.dorico`. Each one finds
its events with the reader, acts on them by the ids the file gives, and reads the result back from a saved copy.

- W1, text. Deleting a text by its ids and creating one with new words in the same stream at the same position
  works; `createText` works on a stave stream too. `Edit.FlipItem` stores `kTextEventAboveOrBelow = kBelow` for the
  layout on screen, and the same property set by `EventEdit.ChangeProperty` holds in every layout.
  `Edit.ChangeStaffTextToSystemText` turns the selected text into a system text, which is a new event in the timebase
  stream. No route set a paragraph style: three guessed property names through the Properties panel did nothing, and
  `ChangeProperty` stored two invented names as properties without complaint, changing nothing. A text in another
  style, or with formatting inside it, can't be rebuilt as it was.
- W2, lyrics. Deleting a lyric by its ids and entering `NoteInput.StartLyricInput` then
  `NoteInput.AcceptCurrentLyricInput?LyricsEntryAdvanceType=kEndInput&LyricText=glad` on the selected note puts the
  whole word on line 1. Sent the same way, "hap-" became a whole word with the hyphen in it, so syllables need
  another route.
- W3, chord symbols. Deleting the Am by its ids, selecting a note at the same position and entering `Dm7` with the
  chord-symbol commands gave a Dm7 there (`kMinor`, `k7`).
- W4, many texts. 300 `createText` calls took 18.7 s, about 62 ms each, and all 300 read back. Reading the copy took
  1.3 s.
- W5, accidentals. `EventEdit.ChangeProperty` with `kNoteAccidentalVisibility_v3` takes `kRoundBrackets`,
  `kSquareBrackets`, `kShow` and `kHide`, writing the older `kNoteAccidentalVisibility` beside each (`kParenthesise`
  for both bracket kinds); it stores `kDefault`, or any other value, as `kHide`. The command with no `Value`, and the
  Properties panel's enable switch on a selection, both take the property off. The panel's route on a selection with
  the full score on screen stores layout 0, as the menu commands do, so a value set by id (no context) is told apart
  from one set by hand. One `Edit.Undo` from outside took back a run's `ChangeProperty` and its `createText`
  together: the property joins the run's one undo step.
- W6, showing a problem. A colour set by `ChangeProperty` holds in every layout and reads back
  (`tests/dorico/case_reader.lua`). The only command found that creates a comment, `NoteInput.ShowCommentDialog`, opens
  a dialog.
- W7, the selection. Marking the selection with `UI.InvokePropertyChangeValue?Type=kEventColour` and reading a saved
  copy finds every selected event, texts included: their colour is stored for layout 0. The enable switch takes the
  marks off again, leaving nothing behind. It would also take off a colour a selected item already had, so a plug-in
  notes those from a saved copy first and puts them back by the same route. The panel ignores a property Dorico
  doesn't know, so a private marker isn't possible. `EventEdit.Select` replaces the selection; the probe's attempt to
  add to it with an `Add` parameter did nothing.
