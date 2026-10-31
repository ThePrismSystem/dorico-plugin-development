# Dorico plug-in development

Example scripts, a guide and a reader library for Lua scripts that read a whole Dorico 6 score and change it.

Dorico 6 can run Lua scripts, but Steinberg documents almost none of it: how to read the notes, which player a voice
belongs to, how to select something, what undo does. Everything here was found out by trying it on a scratch copy of a
project, and every example is run in Dorico by an automated test. Lua on its own reads little of a score, so the library
here reads a saved copy of the open project instead: every note with its notehead, colour and other properties, texts,
lyrics, chord symbols, dynamics, and key and time signatures, matched to Lua by event id. It's for anyone who wants to
automate Dorico: a composer or arranger who has written plug-ins for Sibelius or MuseScore, or just a few scripts, and a
developer building a full plug-in.

## What's here

- [examples/fundamentals](examples/fundamentals): nineteen short scripts, one technique each, numbered in the order
  to read them.
- [examples/recipes](examples/recipes): ten scripts that do a real job by combining the fundamentals.
- [docs/guide.md](docs/guide.md): how Dorico's Lua scripting works, what doesn't, and the workarounds.
- [docs/reference](docs/reference/README.md): every class and member a scan of Dorico's Lua state found, each marked
  verified, failing or not tried, with the commands tried so far. `types/dorico.lua` has editor definitions.
- [docs/spikes.md](docs/spikes.md): what each probe found, with the probes themselves in `spikes/`.
- [lib/scorereader](lib/scorereader): a pure-Lua library that reads the whole score from a saved copy of the open
  project, with every note's spelling and properties, text, lyrics, chord symbols, dynamics, key and time signatures,
  players and layouts. [docs/file-format.md](docs/file-format.md) describes the `.dorico` format it reads, as worked
  out from projects saved by Dorico 6.0.22 to 6.2.30. `types/scorereader.lua` has its editor definitions.
- [fixtures](fixtures/README.md): the projects the tests read, one folder per Dorico version, including projects from
  [ancientgroove.co.uk](https://ancientgroove.co.uk/dorico/index.html).

The [Handbells Used Chart plug-in](https://github.com/ThePrismSystem/handbells-used-chart-dorico-plugin) is the
full-sized example: a plug-in with a dialog, a pure-Lua core with unit tests, and an in-Dorico test suite.

## Reading the score

Lua alone can't read much of a score: `stream.events` fails on real music, and values set in Dorico's UI, such as
noteheads, colours and accidental brackets, can't be read back. The reader gets round that. It saves a copy of the
open project to the temp folder (`app:save` leaves the project, its file and its undo history as they were), decodes
it and deletes it. Event ids in the copy are the ids Lua uses, so anything the reader finds can be selected or changed
by id.

This script sits two folders below the repository's root, as the examples do, so `../../lib` is the library. Dorico
keeps one Lua state, so it clears the library's modules an earlier run loaded. The saved copy goes in the temp folder,
whose path must be all ASCII: `app:save` and Lua's `io.open` spell other characters differently. If it isn't, pass
another folder as `savedcopy.read(app, { dir = ... })`.

```lua
local lib = debug.getinfo(1, "S").source:match("^@(.*[/\\])") .. "../../lib/?.lua"
for name in pairs(package.loaded) do
  if name:match("^scorereader") then package.loaded[name] = nil end
end
if not package.path:find(lib, 1, true) then package.path = lib .. ";" .. package.path end
local savedcopy = require("scorereader.dorico.savedcopy")
local edit = require("scorereader.dorico.edit")
local score = require("scorereader.score")

local app = DoApp.DoApp()
local ok, s = pcall(savedcopy.read, app)
if not ok then return print("The reader couldn't read this project: " .. tostring(s)) end
for _, e in ipairs(score.eventsOf(s, s.flows[1], s.players[1])) do
  if e.kind == "note" and e.spelling:find("#") then
    edit.setProperty(app, e, "kNoteAccidentalVisibility_v3", "kRoundBrackets")
  end
end
```

A read of the fixtures takes 0.8 to 1.6 s in Dorico, `app:save` included. Large scores take longer: decoding Holst's
*The Planets* (122,366 events) takes 6.7 s in stock Lua ([Reading speed](docs/spikes.md#reading-speed)).

## Requirements

- Dorico 6 Pro. Dorico Elements and SE have no Script menu.
- Tested on Dorico 6.2.30 on Windows 11. The Mac parts (where to put scripts, the Mac box in 17) are written from
  Apple's and Dorico's documentation and haven't been run on a Mac.

## Running an example

1. Open a project. Try an example on a copy first: most change the score.
2. Choose Script > Run Script and pick the `.lua` file.
3. Open Script > Show Script Console to read what it printed. Lines printed while the console was closed are kept.

To have a script in the Script menu, copy it into Dorico's Script Plug-ins folder (on Windows,
`%APPDATA%\Steinberg\Dorico 6\Script Plug-ins\`) and restart Dorico. Each example is one file, and starts with comment
lines saying what it does, what it changes, how to undo it, and which examples it builds on. Fundamentals 04 to 09
and 13, and every recipe but colour-by-pitch and hotkey-colour-cycle, load the reader from `lib/`, so copy the `lib`
folder into Script Plug-ins beside them.

## The examples

| Example | What it does | Changes the project? |
| ------- | ------------ | -------------------- |
| [01-hello](examples/fundamentals/01-hello.lua) | Prints Dorico's version and the project's title and counts. | No |
| [02-walk-the-score](examples/fundamentals/02-walk-the-score.lua) | Lists players, flows and which player each voice belongs to. | No |
| [03-read-notes](examples/fundamentals/03-read-notes.lua) | Prints every note: flow, player, voice, position, duration, pitch. | No |
| [04-read-the-saved-copy](examples/fundamentals/04-read-the-saved-copy.lua) | Prints each note's notehead and colour, read from a saved copy. | No |
| [05-names-and-titles](examples/fundamentals/05-names-and-titles.lua) | Reads the title, flow titles, players, instruments and layouts from a saved copy. | No |
| [06-match-by-event-id](examples/fundamentals/06-match-by-event-id.lua) | Matches every stream's dump to the saved copy by event id. | No |
| [07-values-per-layout](examples/fundamentals/07-values-per-layout.lua) | Prints each note's properties with the layouts they apply to. | No |
| [08-text-lyrics-chords-dynamics](examples/fundamentals/08-text-lyrics-chords-dynamics.lua) | Prints every text, lyric, chord symbol and dynamic. | No |
| [09-bars-keys-and-times](examples/fundamentals/09-bars-keys-and-times.lua) | Prints key and time signatures and each note's bar and beat. | No |
| [10-commands](examples/fundamentals/10-commands.lua) | Renames the first flow by command, showing how to escape values. | Yes; one Edit > Undo |
| [11-act-on-the-selection](examples/fundamentals/11-act-on-the-selection.lua) | Finds the selected notes and writes each one's name above it. | Yes; one Edit > Undo |
| [12-select-by-id](examples/fundamentals/12-select-by-id.lua) | Selects each note above F5 by id and colours it red. | Yes; one Edit > Undo |
| [13-set-a-property-by-id](examples/fundamentals/13-set-a-property-by-id.lua) | Colours each note above F5 by event id, in every layout. | Yes; one Edit > Undo |
| [14-add-notes-rests-text](examples/fundamentals/14-add-notes-rests-text.lua) | Adds a flow and writes notes, a chord, a rest and a text in it. | Yes; one Edit > Undo |
| [15-layout-and-notation-options](examples/fundamentals/15-layout-and-notation-options.lua) | Hides the flow headings and sets a final barline. | Yes; one Edit > Undo |
| [16-flows-and-players](examples/fundamentals/16-flows-and-players.lua) | Adds a flow and a player, names them, keeps the player to the new flow. | Yes; one Edit > Undo |
| [17-ask-and-report](examples/fundamentals/17-ask-and-report.lua) | Asks for a word in a box, then adds a flow with it. | Yes, unless cancelled; one Edit > Undo |
| [18-undo](examples/fundamentals/18-undo.lua) | Shows what Edit.Undo inside a script takes back. | No |
| [19-key-command](examples/fundamentals/19-key-command.lua) | Counts its own runs, as a script on a key would; says how to bind a key. | No |
| [colour-by-pitch](examples/recipes/colour-by-pitch.lua) | Colours every note by pitch class, C red through B magenta. | Yes; one Edit > Undo |
| [label-notes](examples/recipes/label-notes.lua) | Writes trumpet valve numbers (or note names) above one player's notes. | Yes; one Edit > Undo |
| [proofread](examples/recipes/proofread.lua) | Reports notes outside their instrument's ranges, by bar and beat. | No |
| [chord-symbols](examples/recipes/chord-symbols.lua) | Names the piano's chords bar by bar and writes them in as chord symbols. | Yes; three Edit > Undo presses per chord symbol |
| [instrument-report](examples/recipes/instrument-report.lua) | Lists each flow's players, instruments, note counts and the most playing at once. | No |
| [hotkey-colour-cycle](examples/recipes/hotkey-colour-cycle.lua) | Colours the selection, moving to the next colour on each quick rerun. | Yes; one Edit > Undo per run |
| [parallel-fifths](examples/recipes/parallel-fifths.lua) | Flags consecutive fifths and octaves between every pair of parts, colouring the notes and listing them. | Yes, unless cancelled; one Edit > Undo |
| [note-names](examples/recipes/note-names.lua) | Writes each note's name under it: letters, German names, fixed or movable do, or scale degrees. | Yes, unless cancelled; one Edit > Undo |
| [cautionary-accidentals](examples/recipes/cautionary-accidentals.lua) | Adds cautionary accidentals by your own rules (bars back, rests, ties, other staves), and can take them back. | Yes, unless cancelled; one Edit > Undo |
| [find-and-replace](examples/recipes/find-and-replace.lua) | Finds words in texts, lyrics and chord symbols, and replaces them where a script can. | Replace only; one Edit > Undo, and more for each chord symbol. Find changes nothing |

## What the probes changed

Some examples are smaller than planned, or work differently, because a probe showed what Dorico allows
([docs/spikes.md](docs/spikes.md)):

- The proofreading recipe has no check for incomplete bars. Rests removed with Edit > Remove Rests leave no trace a
  script can see.
- A colour set by command, or in the Properties panel, can't be read back from Lua, because Dorico stores it for the
  layout on screen. A saved copy reads it, and the colour recipes' tests check the exact colour through fundamental 04.
- Edits made through the object model are undoable, against what the handbells plug-in's guide says. So 11 finds
  the selection by moving it an octave and back instead of undoing, which keeps its labels in one undo step.
- Binding a script to a key of its own means editing Dorico's key-command file and restarting Dorico. 19 and the
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

That also runs every example in Dorico and checks what it did, which takes a while. It needs Dorico 6 running with
Remote Control turned on in its preferences. The first time, Dorico asks you to allow the test client, and the session
token is kept in `.dorico-token`. To use a client name Dorico already allows, set `DORICO_CLIENT_NAME` or put the name
in `.dorico-client-name`.

The tests never touch your own projects. Each copies a fixture from the newest version's folder (now
`fixtures/6.2.30`) into a scratch folder, `%TEMP%\dorico-examples-run`: `reading.dorico` for 07 to 09 and
`sample.dorico` for the rest. It opens the copy and closes it unsaved. The script inside Dorico checks that the active
project is that copy before changing anything, and refuses if it isn't. Your own projects can stay open; Dorico goes
back to them when the tests close their copy. The test for 17 answers the example's box itself, and Dorico runs nothing
else while the box is open.

### Linting and security scans

```bash
pip install -r requirements-dev.txt
npm ci
python tools/lint.py
```

That runs the linters and security scanners CI runs over every file git tracks, and says how to install any tool it
can't find. The first two lines install ruff, zizmor, typos and markdownlint, and `lint.py` says where to get the
others. [SECURITY.md](SECURITY.md) lists every check, and what each example runs and writes.

## Credits

- [ConsoleTools](https://forums.steinberg.net/t/introducing-consoletools-a-lua-framework-to-make-dorico-scripts-more-accessible/848477)
  by notenlektorat showed that a key command can run a script and that state survives between runs.
- [DoricoUse](https://github.com/Delsin-Yu/DoricoUse) by Delsin-Yu is an independent map of the same object model,
  with constructor signatures and the `Info.lua` plug-in format.
- The guide grew out of the Handbells Used Chart plug-in's.

Neither project's code or text is copied here.

## Licence

MIT. See [LICENSE](LICENSE).
