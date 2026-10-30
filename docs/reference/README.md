# Object-model reference

What Dorico 6's Lua scripting offers, class by class, as far as this repository has mapped it. Steinberg doesn't
publish this API, so everything here comes from a scan of Lua's registry and from probes and examples run on
Dorico 6.2.30. [The guide](../guide.md) explains how the pieces fit together.

## Classes

The classes the examples use each have a page:

- [The app](app.md): `DoApp.DoApp`, the starting point, and `DoUI.DoUI`
- [The score](score.md): `DoScore.Score`, the open project, and its libraries
- [Flows](flow.md): `DoCore.Flow` and its element tables
- [Players](player.md): `DoCore.Player`
- [Instruments](instrument.md): `DoCore.Instrument` and `DoCore.FlowInstrument`
- [Layouts](layout.md): `DoCore.Layout`
- [Event streams](event-stream.md): `DoCore.EventStream`, where the music is
- [Events](events.md): notes, rests, texts and the other kinds
- [Blocks and block instances](block-instance.md): what selecting an event needs
- [Properties](properties.md): an event's property table
- [Values](values.md): `RhythmicLength`, `MIDIPitchWithSpelling`, `Variant` and others
- [The script host](script-host.md): `DoCore.ScriptHost`, not yet reached

[Other classes](other-classes.md) lists every other class the scan found, with whatever members it could match.

## Commands and the Remote Control API

- [Commands](commands.md): the commands the examples and probes have run, with their parameters and what they did.
- [The Remote Control API](remote-api.md): the messages the tests use to drive Dorico from outside.

## How the reference is made

1. `python tools/run_lua.py spikes/class_members.lua --open fixtures/6.2.30/sample.dorico` scans the registry on a scratch
   copy of the sample and writes `members-raw.json` to the run folder. It reads names only and calls nothing.
2. `python tools/members.py` names the tables of instance members by what they hold and writes
   [members.json](members.json).
3. The pages and `types/dorico.lua` give each member a kind, a status and a note. `tests/test_reference.py` fails if
   a class or member in `members.json` is missing from them.

Each member's status is one of:

- verified: an example or probe used it, and it did what the note says;
- fails: it was tried and doesn't work, with what happened;
- not tried: nothing here has called it. Don't call one on a project you care about, since a bad call can crash
  Dorico.

## Editor support

`types/dorico.lua` has definitions for the classes with pages, in the annotation format lua-language-server reads.
Add the `types` folder to `Lua.workspace.library` in your editor's settings, and `app.currentScore.flows` gets
completion and types.
