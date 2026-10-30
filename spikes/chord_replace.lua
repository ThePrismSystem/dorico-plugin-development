-- Can a chord symbol be replaced by entering a new one over it, without deleting it first, and what does a definition
-- Dorico can't read do? Enters "Dm" on a note under the texts fixture's Am, then "Xyzzy" on a note under its G7, and
-- reads the chord symbols back after each. Run on a scratch copy of the texts fixture:
--   python tools/run_lua.py spikes/chord_replace.lua --open fixtures/6.2.30/texts.dorico
local here = debug.getinfo(1, "S").source:match("^@(.*[/\\])")
local repo = here .. "../"
local mine = here .. "lib/?.lua;" .. repo .. "lib/?.lua"
for name in pairs(package.loaded) do
  if name:match("^scorereader") or package.searchpath(name, mine) then package.loaded[name] = nil end
end
if not package.path:find(mine, 1, true) then package.path = mine .. ";" .. package.path end
local probe = require("probe")

probe.run("chord_replace", function(p)
  local savedcopy = require("scorereader.dorico.savedcopy")
  local commands = require("scorereader.dorico.commands")
  local edit = require("scorereader.dorico.edit")
  local values = require("scorereader.values")
  local app = DoApp.DoApp()
  local opts = { dir = probe.runDir }
  app:doCommand("NoteInput.Exit")
  app:doCommand("Window.SwitchMode?WindowMode=kWriteMode")

  local function chords(s)
    local out = {}
    for _, e in ipairs(s.flows[1].events) do
      if e.kind == "chordSymbol" then
        out[#out + 1] = string.format("%s id %d %s (%s %s %s)", values.positionText(e.position), e.id, tostring(e.name),
          e.root, e.rawQuality, e.rawInterval)
      end
    end
    return out
  end
  local function noteAt(s, pos)
    for _, e in ipairs(s.flows[1].events) do
      if e.kind == "note" and values.toNumber(e.position) == pos then return e end
    end
  end
  local function enter(s, pos, definition)
    edit.select(app, noteAt(s, pos))
    app:doCommand("NoteInput.StartChordSymbolInput")
    app:doCommand(commands.build("NoteInput.AcceptCurrentChordSymbolTextInput",
      { { "Definition", definition }, { "ChordSymbolEntryAdvanceType", "kEndInput" } }))
    app:doCommand("Edit.SelectNone")
  end

  local s = savedcopy.read(app, opts)
  p:fact("before", chords(s))
  enter(s, 4, "Dm")
  s = savedcopy.read(app, opts)
  p:fact("afterDmOverAm", chords(s))
  enter(s, 8, "Xyzzy")
  s = savedcopy.read(app, opts)
  p:fact("afterXyzzyOverG7", chords(s))
end)
