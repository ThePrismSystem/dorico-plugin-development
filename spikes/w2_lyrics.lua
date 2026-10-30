-- Spike W2: can a script create and replace lyrics? On a scratch copy of the reading fixture, deletes the soprano's
-- "joy" by its ids from the file and enters "glad" on the same note, then enters "hap-" on a note that has no lyric,
-- through the lyrics popover's commands, and reads every lyric back from a saved copy.
--   python tools/run_lua.py spikes/w2_lyrics.lua --open fixtures/6.2.30/reading.dorico --timeout 120
local here = debug.getinfo(1, "S").source:match("^@(.*[/\\])")
local repo = here .. "../"
local mine = here .. "lib/?.lua;" .. repo .. "lib/?.lua"
for name in pairs(package.loaded) do
  if name:match("^scorereader") or package.searchpath(name, mine) then package.loaded[name] = nil end
end
if not package.path:find(mine, 1, true) then package.path = mine .. ";" .. package.path end
local probe = require("probe")

probe.run("w2_lyrics", function(p)
  local savedcopy = require("scorereader.dorico.savedcopy")
  local edit = require("scorereader.dorico.edit")
  local values = require("scorereader.values")
  local score = require("scorereader.score")
  local app = DoApp.DoApp()
  local opts = { dir = probe.runDir }
  app:doCommand("NoteInput.Exit")
  app:doCommand("Window.SwitchMode?WindowMode=kWriteMode")
  local s = savedcopy.read(app, opts)
  local soprano
  for _, pl in ipairs(s.players) do
    if pl.name == "Soprano" then soprano = pl end
  end
  local joy, noteAt = nil, {}
  for _, e in ipairs(score.eventsOf(s, s.flows[1], soprano)) do
    if e.kind == "lyric" and e.text == "joy" then joy = e end
    if e.kind == "note" then noteAt[values.positionText(e.position)] = e end
  end

  local function enter(note, text)
    edit.select(app, note)
    app:doCommand("NoteInput.StartLyricInput")
    app:doCommand("NoteInput.AcceptCurrentLyricInput?LyricsEntryAdvanceType=kEndInput&LyricText=" .. text)
  end
  edit.select(app, joy)
  app:doCommand("Edit.Delete")
  enter(noteAt[values.positionText(joy.position)], "glad")
  enter(noteAt["12"], "hap-")
  app:doCommand("Edit.SelectNone")

  local after = savedcopy.read(app, opts)
  local lyrics = {}
  for _, e in ipairs(score.eventsOf(after, after.flows[1], soprano)) do
    if e.kind == "lyric" then
      lyrics[#lyrics + 1] = values.positionText(e.position) .. " " .. e.text .. " " .. e.syllable .. " line " .. e.line
    end
  end
  p:fact("lyrics", lyrics)
end)
