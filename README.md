# Dorico plug-in development

Example scripts and a guide for writing Lua scripts that read and change a Dorico 6 score.

Dorico 6 can run Lua scripts, but Steinberg documents almost none of it: how to read the notes, which player a voice
belongs to, how to select something, what undo does. Everything here was found out by trying it on a scratch copy of
a project, and every example is run in Dorico by an automated test. It's for anyone who wants to automate Dorico: a
composer or arranger who has written plug-ins for Sibelius or MuseScore, or just a few scripts, and a developer
building a full plug-in.

## What's here

- [examples/fundamentals](examples/fundamentals): fourteen short scripts, one technique each, numbered in the order
  to read them.
- [examples/recipes](examples/recipes): six scripts that do a real job by combining the fundamentals.
- [docs/guide.md](docs/guide.md): how Dorico's Lua scripting works, what doesn't, and the workarounds.
- [docs/reference](docs/reference/README.md): every class and member a scan of Dorico's Lua state found, each marked
  verified, failing or not tried, with the commands tried so far. `types/dorico.lua` has editor definitions.
- [docs/spikes.md](docs/spikes.md): what each probe found, with the probes themselves in `spikes/`.

The [Handbells Used Chart plug-in](https://github.com/ThePrismSystem/handbells-used-chart-dorico) is the full-sized
example: a plug-in with a dialog, a pure-Lua core with unit tests, and an in-Dorico test suite.

## Requirements

- Dorico 6 Pro. Dorico Elements and SE have no Script menu.
- Tested on Dorico 6.2.30 on Windows 11. The Mac parts (where to put scripts, the Mac box in 12) are written from
  Apple's and Dorico's documentation and haven't been run on a Mac.

## Running an example

1. Open a project. Try an example on a copy first: most change the score.
2. Choose Script > Run Script and pick the `.lua` file.
3. Open Script > Show Script Console to read what it printed. Lines printed while the console was closed are kept.

To have a script in the Script menu, copy it into Dorico's Script Plug-ins folder (on Windows,
`%APPDATA%\Steinberg\Dorico 6\Script Plug-ins\`) and restart Dorico. Each example is one file, with nothing beside
it, and starts with comment lines saying what it does, what it changes, how to undo it, and which examples it builds
on.

## The examples

| Example | What it does | Changes the project? |
| ------- | ------------ | -------------------- |
| [01-hello](examples/fundamentals/01-hello.lua) | Prints Dorico's version and the project's title and counts. | No |
| [02-walk-the-score](examples/fundamentals/02-walk-the-score.lua) | Lists players, flows and which player each voice belongs to. | No |
| [03-read-notes](examples/fundamentals/03-read-notes.lua) | Prints every note: flow, player, voice, position, duration, pitch. | No |
| [04-noteheads-and-colours](examples/fundamentals/04-noteheads-and-colours.lua) | Prints each note's notehead and colour, through a pasted copy. | No, but it uses the clipboard |
| [05-names-from-the-text-export](examples/fundamentals/05-names-from-the-text-export.lua) | Reads the title, file path, flow titles and instrument names from the text export. | No |
| [06-commands](examples/fundamentals/06-commands.lua) | Renames the first flow by command, showing how to escape values. | Yes; one Edit > Undo |
| [07-act-on-the-selection](examples/fundamentals/07-act-on-the-selection.lua) | Finds the selected notes and writes each one's name above it. | Yes; one Edit > Undo |
| [08-select-by-id](examples/fundamentals/08-select-by-id.lua) | Selects each note above F5 by id and colours it red. | Yes; one Edit > Undo |
| [09-add-notes-rests-text](examples/fundamentals/09-add-notes-rests-text.lua) | Adds a flow and writes notes, a chord, a rest and a text in it. | Yes; one Edit > Undo |
| [10-layout-and-notation-options](examples/fundamentals/10-layout-and-notation-options.lua) | Hides the flow headings and sets a final barline. | Yes; one Edit > Undo |
| [11-flows-and-players](examples/fundamentals/11-flows-and-players.lua) | Adds a flow and a player, names them, keeps the player to the new flow. | Yes; one Edit > Undo |
| [12-ask-and-report](examples/fundamentals/12-ask-and-report.lua) | Asks for a word in a box, then adds a flow with it. | Yes, unless cancelled; one Edit > Undo |
| [13-undo](examples/fundamentals/13-undo.lua) | Shows what Edit.Undo inside a script takes back. | No |
| [14-key-command](examples/fundamentals/14-key-command.lua) | Counts its own runs, as a script on a key would; says how to bind a key. | No |
| [colour-by-pitch](examples/recipes/colour-by-pitch.lua) | Colours every note by pitch class, C red through B magenta. | Yes; one Edit > Undo |
| [label-notes](examples/recipes/label-notes.lua) | Writes trumpet valve numbers (or note names) above one player's notes. | Yes; one Edit > Undo |
| [proofread](examples/recipes/proofread.lua) | Reports notes out of range and parallel fifths and octaves, by bar and beat. | No |
| [chord-symbols](examples/recipes/chord-symbols.lua) | Names the piano's chords and writes them in as chord symbols. | Yes; three Edit > Undo presses per chord symbol |
| [instrument-report](examples/recipes/instrument-report.lua) | Lists each flow's players, instruments, note counts and the most playing at once. | No |
| [hotkey-colour-cycle](examples/recipes/hotkey-colour-cycle.lua) | Colours the selection, moving to the next colour on each quick rerun. | Yes; one Edit > Undo per run |

A script that makes and deletes marker texts (05, proofread, instrument-report) leaves the project as it was, but the
markers still make an undo step, so one Edit > Undo straight afterwards changes nothing you can see.

## What the probes changed

Some examples are smaller than planned, or work differently, because a probe showed what Dorico allows
([docs/spikes.md](docs/spikes.md)):

- The proofreading recipe has no check for incomplete bars. Rests removed with Edit > Remove Rests leave no trace a
  script can see.
- Lua can't read time signatures, so the chord-symbols recipe names a chord wherever three or more pitch classes
  sound, not bar by bar, and the proofreading recipe finds bar numbers through the text export.
- A colour set by command, or in the Properties panel, can't be read back: a script can tell that a note has a
  colour, but not which. The colour recipes are checked for the colour being there.
- Edits made through the object model are undoable, against what the handbells plug-in's guide says. So 07 finds
  the selection by moving it an octave and back instead of undoing, which keeps its labels in one undo step.
- Binding a script to a key of its own means editing Dorico's key-command file and restarting Dorico. 14 and the
  hotkey recipe describe that and use Run Last Script (Ctrl+Shift+Alt+R) instead, which needs no setup. The
  key-command entry hasn't been tried.
- Working through a folder of other projects works (S5) but has no example of its own.

## Running the tests

```bash
python tools/run_tests.py
```

That runs the Python and stock Lua 5.2 unit tests and checks every Lua file's syntax, as CI does. It needs Python 3
and Lua 5.2 (`lua52` on the path, or `C:/ProgramData/chocolatey/lib/lua52/tools/lua52.exe`).

```bash
python tools/run_tests.py --dorico
```

That also runs every example in Dorico and checks what it did, which takes ten minutes or so. It needs Dorico 6
running with Remote Control turned on in its preferences. The first time, Dorico asks you to allow the test client,
and the session token is kept in `.dorico-token`. To use a client name Dorico already allows, set
`DORICO_CLIENT_NAME` or put the name in `.dorico-client-name`.

The tests never touch your own projects. Each copies the sample (`fixtures/6.2.30/sample.dorico`) into a scratch
folder, `%TEMP%\dorico-examples-run`, opens the copy, and closes it unsaved. The script inside Dorico checks that the
active project is that copy before changing anything, and refuses if it isn't. Your own projects can stay open;
Dorico goes back to them when the tests close their copy. The test for 12 answers the example's box itself, and Dorico runs
nothing else while the box is open.

## Credits

- [ConsoleTools](https://forums.steinberg.net/t/introducing-consoletools-a-lua-framework-to-make-dorico-scripts-more-accessible/848477)
  by notenlektorat showed that a key command can run a script and that state survives between runs.
- [DoricoUse](https://github.com/Delsin-Yu/DoricoUse) by Delsin-Yu is an independent map of the same object model,
  with constructor signatures and the `Info.lua` plug-in format.
- The guide grew out of the Handbells Used Chart plug-in's.

Neither project's code or text is copied here.

## Licence

MIT. See [LICENSE](LICENSE).
