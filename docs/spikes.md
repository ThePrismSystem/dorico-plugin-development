# What the spikes found

Each spike asked one question about Dorico 6's Lua scripting that the examples needed answered. The probes are in
`spikes/`, run on scratch copies with `python tools/run_lua.py spikes/<probe>.lua --open fixtures/sample.dorico`.
Everything here was seen on Dorico 6.2.30 (build 6245) on Windows 11.

## The sample project's import

`fixtures/build_sample.py` imports MusicXML, and the import shaped the sample:

- A tied pair comes in as one note: the flute's C5 tied over the barline is one event lasting three beats.
- Rests come in as implicit rests, which aren't events: no voice stream holds a `kRestEvent`.
- A transposing instrument's player name gains its transposition. A part named "Trumpet Zoë" becomes the player
  `Trumpet Zoë (B{@flat@})`, and `tostring(player)` gives that text, token and all. A part named "Trumpet in B♭"
  became `Trumpet♭ (B)`.
- A MusicXML part's key is its written key, so a B♭ trumpet in a C major piece is written in D major.

## S3: what the dump says

Probes: `s3_dump_details.lua`, `s3_gap.lua`, `s3_element_tables.lua`.

- **Streams.** Each flow has a timebase stream, a stave stream per staff, a player stream per player (empty in the
  sample) and a voice stream per voice.
- **Voice streams** hold notes, grace notes, slurs (`kSlurEvent`, with a duration) and lyrics (`kLyricEvent`).
  Positions and durations are in quarter notes from the start of the flow.
- **Stave streams** hold clefs (`kClefEvent`, with a line naming the clef, such as `clef.treble`) and dynamics
  (`kDynamicGroupEvent`).
- **The timebase stream** holds a `kBarDivisionEvent` for each time signature and a `kTonalityDivisionEvent` for
  each key signature. Each names only an element id.
- **Ties** aren't events: a tied note is one note with the whole length.
- **Implicit rests** aren't listed. Rests the music has as events (from note input, or `createRest`) are.
- **Removed rests leave no trace.** After `Edit.RemoveRests` on the trumpet's bar 5, the page shows the gap, but
  every stream's dump is the same as before. A script can't tell a bar with removed rests from one with implicit
  rests, so the proofreading recipe has no incomplete-bar check.
- **`flow.elementTables`** has `barDivisions`, `dynamics` and `tonalityDivisions`:
  - Dynamics can be read. Each dynamic's sub-element has `kDynamicImmediateChangeBasicType` (0 for the sample's
    mf, 1 for its p) and `kDynamicImmediateChangeIsMezzo` (true, false). The intensity itself fails with "Invalid
    conversion".
  - Time signatures can't. A bar division element has properties such as `kBarDivisionIrregularBarLength`, but
    `kBarDivisionTimeSignatures` fails with "Invalid conversion". A script can't read the meter.
  - Key signatures can't: reading `tonalityDivisions` raises "Trying to use unregistered class".

## S6: where print goes

Probe: `s6_print.lua`, driven by `s6_print.py`.

`print` writes to Dorico's Script Console (**Script > Show Script Console**). Lines printed while the console is
closed are kept and appear when it opens. `io.write` output appears nowhere. A script can open the console itself
with `app:doCommand("Script.ShowConsole")`. The console opens with "Always on top" ticked.

So the examples report with `print` and open the console first.

## S8: reading and setting note properties

Probes: `s8_properties.lua`, `s8_colour_read.lua`.

- A note's property table lists only the properties it has: `kEventPosition`, `kEventDuration`, `kNotePitch`
  (the MIDI number) and a few more, until something sets another.
- **Setting a colour by command works on the selected notes:** `UI.InvokePropertyChangeValue?Type=kEventColour&Value=`
  followed by `#ffff0000`, `string: "#ffff0000"` or `string: "#0000ff"`. All three coloured their note. The change
  is a command, so Edit > Undo takes it back.
- **Setting a colour through the property table works too,** on an event object from `stream.events`:
  `propertyTable:set("kEventColour", DoCore.Variant.createString("#ff8000ff"), ctx)`. It's not in the undo history,
  and it needs the event object, which a stream holding lyrics or slurs can't give.
- **A colour set by command can't be read back.** The property is listed, but its Variant has `type` -1 and
  `valid` false, and `tostring` gives "". A colour set from Lua reads back as the string it was set to. So a script
  can tell that a note has a colour, but not which one, unless a script set it.
- `UI.InvokePropertyChangeValue?Type=kNoteheadSetOverride&Value=string: "noteheadset.diamondNoteheads"` changed
  nothing.

## S1: reading the selection

Probes: `s1_read_selection.lua`, driven by `s1_selection.py`; `select_note.lua` makes the selections.

Lua has no selection API, but a script can find out which notes are selected:

1. Dump every voice stream.
2. Run `NoteEdit.PitchUpChromatic`, which moves only the selected notes up a semitone.
3. Dump again. The notes whose spelling changed are the selection.
4. Run `Edit.Undo` once. Inside a script it takes back that run's own command edits, so the music is as it was.

With one violin note selected, it found that note. With a second added (`EventEdit.NavigateRightExtend`), it found
both. With nothing selected, it found nothing. Each time every stream's dump afterwards was identical to before.

The costs: it uses the run's one `Edit.Undo` (a second would take back the user's own last edit), it finds notes
and grace notes but no other items, a note that can't go a semitone higher won't show, and Edit > Redo afterwards
would put the semitone back. The Remote API's status (`hasSelection`, `selectedEventType`: `kNoteEvent`, `kMixed`,
`kNone`) says what kind of thing is selected, but only to a program outside Dorico.

## S4: creating items

Probes: `s4_create.lua` (commands sent from Lua), `s4_record.py` (Dorico's popovers, typed into the scratch window,
with `application.log` read for the commands they ran).

Each was tried with one piano note selected by id:

- **Chord symbols:** `NoteInput.StartChordSymbolInput`, then
  `NoteInput.AcceptCurrentChordSymbolTextInput?Definition=C7&ChordSymbolEntryAdvanceType=kEndInput`. This is what
  the chord symbol popover runs. It makes a `kChordSymbolEvent` in the timebase stream, and the dump names it
  (`kChordSymbolEvent (id:326) at 0  C  0`). The accept command alone makes nothing.
- **Dynamics:** `NoteInput.CreateDynamic?Definition=mf` makes a `kDynamicGroupEvent` in the stave stream.
  `Dynamic=ff` makes nothing.
- **Staff text: never by command.** `NoteInput.CreateText` opens Dorico's text editor at the note and waits for
  typing, and while it is open Dorico runs no scripts at all. Escape sent with an Alt press (to bring the window
  forward) only toggles the menu bar; clicking empty paper closes the editor. Use `stream:createText(position,
  duration, text)` instead, which the handbells plug-in has used throughout.
- `NoteInput.CreatePlayingTechnique?Definition=pizz.` made nothing.
- Dorico also has `Edit.GenerateChordSymbolsFromSelection`, its own chord detection, not tried here.
