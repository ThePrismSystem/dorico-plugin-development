-- Spike W3: can a script replace a chord symbol? On a scratch copy of the reading fixture, deletes the Am at beat 9 by
-- its ids from the file, selects the flute's note at the same position, and enters Dm7 through the commands the
-- chord-symbols recipe uses, then reads the chord symbols back from a saved copy.
--   python tools/run_lua.py spikes/w3_chord_replace.lua --open fixtures/6.2.30/reading.dorico
local here = debug.getinfo(1, "S").source:match("^@(.*[/\\])")
local repo = here .. "../"
local mine = here .. "lib/?.lua;" .. repo .. "lib/?.lua"
for name in pairs(package.loaded) do
  if name:match("^scorereader") or package.searchpath(name, mine) then package.loaded[name] = nil end
end
if not package.path:find(mine, 1, true) then package.path = mine .. ";" .. package.path end
local probe = require("probe")

probe.run("w3_chord_replace", function(p)
  local savedcopy = require("scorereader.dorico.savedcopy")
  local edit = require("scorereader.dorico.edit")
  local values = require("scorereader.values")
  local score = require("scorereader.score")
  local app = DoApp.DoApp()
  local opts = { dir = probe.runDir }
  app:doCommand("NoteInput.Exit")
  app:doCommand("Window.SwitchMode?WindowMode=kWriteMode")
  local s = savedcopy.read(app, opts)
  local chord, note
  for _, e in ipairs(s.flows[1].events) do
    if e.kind == "chordSymbol" and e.name == "Am" then chord = e end
  end
  for _, e in ipairs(score.eventsOf(s, s.flows[1], s.players[1])) do
    if not note and e.kind == "note" and values.positionText(e.position) == values.positionText(chord.position) then
      note = e
    end
  end
  edit.select(app, chord)
  app:doCommand("Edit.Delete")
  edit.select(app, note)
  app:doCommand("NoteInput.StartChordSymbolInput")
  app:doCommand("NoteInput.AcceptCurrentChordSymbolTextInput?Definition=Dm7&ChordSymbolEntryAdvanceType=kEndInput")
  app:doCommand("Edit.SelectNone")
  local after = savedcopy.read(app, opts)
  local chords = {}
  for _, e in ipairs(after.flows[1].events) do
    if e.kind == "chordSymbol" then
      chords[#chords + 1] = values.positionText(e.position) .. " " .. tostring(e.name) .. " (" .. e.root .. " "
        .. e.rawQuality .. " " .. e.rawInterval .. ")"
    end
  end
  p:fact("chords", chords)
end)
