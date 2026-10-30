-- Spike W4: how quickly can a script add many texts? On a scratch copy of the reading fixture, creates 300 texts in the
-- flute's voice (ten to a quarter note), times it, and counts them back from a saved copy.
--   python tools/run_lua.py spikes/w4_bulk_text.lua --open fixtures/6.2.30/reading.dorico
local here = debug.getinfo(1, "S").source:match("^@(.*[/\\])")
local repo = here .. "../"
local mine = here .. "lib/?.lua;" .. repo .. "lib/?.lua"
for name in pairs(package.loaded) do
  if name:match("^scorereader") or package.searchpath(name, mine) then package.loaded[name] = nil end
end
if not package.path:find(mine, 1, true) then package.path = mine .. ";" .. package.path end
local probe = require("probe")

local COUNT = 300

probe.run("w4_bulk_text", function(p)
  local savedcopy = require("scorereader.dorico.savedcopy")
  local app = DoApp.DoApp()
  local voice = app.currentScore.flows[1].voiceStreams[1]
  local t0 = os.clock()
  for i = 0, COUNT - 1 do
    voice:createText(DoCore.RhythmicLength(i, 10), DoCore.RhythmicLength(0), "n" .. i)
  end
  p:fact("createSeconds", os.clock() - t0)
  local t1 = os.clock()
  local s = savedcopy.read(app, { dir = probe.runDir })
  p:fact("readSeconds", os.clock() - t1)
  local found = 0
  for _, e in ipairs(s.flows[1].events) do
    if e.kind == "text" and e.words:match("^n%d+$") then found = found + 1 end
  end
  p:check("every text reads back", found == COUNT, found)
end)
