# Commands

The commands that the examples, the probes and the handbells plug-in have run with `app:doCommand`, with their
parameters and what happened. A command is written `Name?key=value&key=value`, with `\`, `&` and `,` in a value
escaped by a backslash ([the guide](../guide.md#6-commands)). `doCommand` returns nothing whether or not a command
works, so "verified" means the project was read afterwards and showed the change.

Dorico has hundreds more. Its own `keycommands_en.json` (in its program folder) lists the ones with default keys,
`application.log` in `%APPDATA%\Steinberg\Dorico 6` records the command behind each menu item you use, and the
Remote Control API's `getcommands` lists them all.

## Selecting

| Command | Parameters | Status | Notes |
| ------- | ---------- | ------ | ----- |
| `EventEdit.Select` | `FlowID`, `EventID`, `EventBlockID` | verified | Selects one event, replacing the selection. The block id comes from `stream.blockInstances` ([08](../../examples/fundamentals/08-select-by-id.lua)). |
| `EventEdit.NavigateRightExtend` | | verified | Adds the next item to the right to the selection. |
| `EventEdit.NavigateDownExtend` | | verified | Extends the selection one staff down ([04](../../examples/fundamentals/04-noteheads-and-colours.lua)). |
| `Edit.SelectNone` | | verified | Clears the selection. |
| `Edit.SelectAll` | | verified | Selects everything in the flow (`spikes/pitch_up_down.lua`). |
| `Edit.SelectToStartOfFlow`, `Edit.SelectAtEndOfFlow` | | verified | Extend the selection to the flow's ends ([04](../../examples/fundamentals/04-noteheads-and-colours.lua)). |
| `Filter.NotesAndChords` | | verified | Keeps only notes and chords in the selection, and the lines attached to them. |

## Editing

| Command | Parameters | Status | Notes |
| ------- | ---------- | ------ | ----- |
| `Edit.Copy`, `Edit.Paste`, `Edit.Delete` | | verified | On the selection ([04](../../examples/fundamentals/04-noteheads-and-colours.lua)). |
| `Edit.Undo` | | verified | Inside a script, takes back everything the run has done so far. Only the first in a run is safe ([13](../../examples/fundamentals/13-undo.lua)). |
| `Edit.RemoveRests` | | verified | On the selection. Leaves no trace in the dump. |
| `Edit.HideAccidental` | | verified | On the selected note (the handbells plug-in). |
| `EventEdit.ChangeProperty` | `FlowID`, `EventID`, `EventBlockID`, `Type`, `Value` | verified | Sets a property on one event by its ids, with nothing selected, stored for every layout; it joins the run's one undo step. With no `Value` it takes the property off. It stores any name and value without checking: an unknown accidental visibility becomes `kHide` (W5, `spikes/w5_accidentals.lua`). |
| `Edit.ShowAccidentalInParentheses`, `Edit.ShowAccidentalInBrackets` | | verified | On the selected notes; stored only for the layout on screen, layout 0 when the full score is showing (W5). |
| `Edit.SetNoteheadSetOverride` | `NoteheadSetEntityID` | verified | On the selected notes; stored for every layout and the note's block instance (F3). |
| `Edit.FlipItem` | | verified | Flips the selected text above or below, stored as `kTextEventAboveOrBelow` for the layout on screen (W1). |
| `Edit.ChangeStaffTextToSystemText` | | verified | Makes the selected staff text a system text: a new event in the timebase stream (W1). |
| `UI.InvokePropertyEnableSwitch` | `Type`, `Value` | verified | `Value=false` takes the property off the selection, as unticking it in the Properties panel does (W5, W7). Properties Dorico doesn't know are ignored. |
| `Edit.CreateSystemBreak` | | verified | At the selection, which needs a barline there (the handbells plug-in). |
| `Edit.GenerateChordSymbolsFromSelection` | | not tried | Dorico's own chord detection. |
| `NoteEdit.PitchUpOctave`, `NoteEdit.PitchDownOctave` | | verified | Move the selected notes an octave, keeping their spelling ([07](../../examples/fundamentals/07-act-on-the-selection.lua)). |
| `NoteEdit.PitchUpChromatic`, `NoteEdit.PitchDownChromatic` | | verified | Move them a semitone; up and back down can respell (G#4 comes back as Ab4). |
| `UI.InvokePropertyChangeValue` | `Type`, `Value` | verified | Sets a property on the selection, as the Properties panel does: `Type=kEventColour&Value=#ffff0000` colours it ([08](../../examples/fundamentals/08-select-by-id.lua)). With `kNoteheadSetOverride` it changed nothing. |

## Note input

| Command | Parameters | Status | Notes |
| ------- | ---------- | ------ | ----- |
| `NoteInput.Exit` | | verified | Leaves note input; do it before selecting. |
| `NoteInput.StartChordSymbolInput` | | verified | Opens chord symbol input at the selection. |
| `NoteInput.AcceptCurrentChordSymbolTextInput` | `Definition`, `ChordSymbolEntryAdvanceType` | verified | After the command above, `Definition=G7&ChordSymbolEntryAdvanceType=kEndInput` makes the chord symbol. Alone it makes nothing. Each chord symbol takes three undo steps ([chord-symbols](../../examples/recipes/chord-symbols.lua)). |
| `NoteInput.StartLyricInput` | | verified | Opens lyric input at the selected note (W2). |
| `NoteInput.AcceptCurrentLyricInput` | `LyricText`, `LyricsEntryAdvanceType` | verified | After the start command, `LyricText=glad&LyricsEntryAdvanceType=kEndInput` puts a whole-word lyric on line 1. A trailing hyphen stays in the word (W2). |
| `NoteInput.CreateDynamic` | `Definition` | verified | `Definition=mf` makes a dynamic at the selection; `Dynamic=ff` makes nothing (S4). |
| `NoteInput.CreateTimeSignature` | `Definition` | verified | `Definition=X` makes an open meter at the selection (the handbells plug-in). |
| `NoteInput.CreateText` | | fails | Opens the text editor and waits for typing; Dorico runs no scripts until someone clicks the page. Use `stream:createText`. |
| `NoteInput.CreatePlayingTechnique` | `Definition` | fails | `Definition=pizz.` made nothing. |

## Flows, players and layouts

| Command | Parameters | Status | Notes |
| ------- | ---------- | ------ | ----- |
| `Project.Flow.New` | | verified | Adds a flow at the end, holding every player ([09](../../examples/fundamentals/09-add-notes-rests-text.lua)). |
| `Project.Flow.Rename` | `FlowID`, `Name` | verified | ([06](../../examples/fundamentals/06-commands.lua)) |
| `Project.Flows.MoveToStart` | `FlowIDArray` | verified | A single id is the whole array (the handbells plug-in). |
| `Project.Flows.Delete` | | verified | Needs Setup mode, and asks the user to confirm (the handbells plug-in). |
| `Project.Player.Rename` | `PlayerID`, `Name`, `ShortName` | verified | Both names optional. Takes a player id, not an instrument id ([11](../../examples/fundamentals/11-flows-and-players.lua)). |
| `Project.Players.DeleteEmpty` | | verified | Opens Dorico's "Delete Empty Players" dialog (the handbells plug-in). |
| `Project.Layouts.Delete` | `LayoutIDArray` | verified | Deletes a layout silently (the handbells plug-in). |
| `Project.Layout.SetOptions` | `Dictionary`, `OpenScoreID`, `LayoutIDArray` | verified | Sets layout options ([10](../../examples/fundamentals/10-layout-and-notation-options.lua)). |
| `Project.Flow.SetNotationOptions` | `Dictionary`, `OpenScoreID`, `FlowIDArray` | verified | Sets a flow's notation options ([10](../../examples/fundamentals/10-layout-and-notation-options.lua)). |

## Files, scripts and the window

| Command | Parameters | Status | Notes |
| ------- | ---------- | ------ | ----- |
| `File.Export.Text` | `File`, `Show` | verified | Writes `<name>.csv` beside the `.txt` it's given, silently with `Show=false` ([05](../../examples/fundamentals/05-names-from-the-text-export.lua)). |
| `File.Open` | `File` | verified | Opens a project, which becomes `app.currentScore` straight away (S5). |
| `File.Save` | | verified | Silent on a saved project; opens Save As on a new one. |
| `File.CloseProject` | `OpenScoreID`, `Save` | verified | `Save=false` closes without saving (S5). |
| `File.Export`, `File.Export.SpecificFlowsAndParts` | | fails | Open dialogs; there's no silent MusicXML export. |
| `Script.RunScript` | `ScriptPath`, `ShowConsole` | verified | Runs a Lua file. Scripts queue up behind each other. |
| `Script.RunLastScript` | | verified | Runs the last script again; Ctrl+Shift+Alt+R by default (S2). |
| `Script.ShowConsole` | | verified | Toggles the Script Console (S6). |
| `Window.SwitchMode` | `WindowMode` | verified | `kWriteMode` before selecting; `kSetupMode` before deleting a flow. |
| `View.ZoomIn` | | verified | Zoomed the view in when a screenshot of a test copy was taken. Nothing in this repository runs it. |
