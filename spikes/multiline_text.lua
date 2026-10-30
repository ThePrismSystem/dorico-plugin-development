-- Spike: does stream:createText keep a newline, so a chord's note names can stack in one text? On a scratch copy of
-- the sample, creates a text with two lines in the first voice, and reads its paragraphs and words back from a saved
-- copy.
--   python tools/run_lua.py spikes/multiline_text.lua --open fixtures/6.2.30/sample.dorico
local here = debug.getinfo(1, "S").source:match("^@(.*[/\\])")
local repo = here .. "../"
local mine = here .. "lib/?.lua;" .. repo .. "lib/?.lua"
for name in pairs(package.loaded) do
  if name:match("^scorereader") or package.searchpath(name, mine) then package.loaded[name] = nil end
end
if not package.path:find(mine, 1, true) then package.path = mine .. ";" .. package.path end
local probe = require("probe")

probe.run("multiline_text", function(p)
  local savedcopy = require("scorereader.dorico.savedcopy")
  local app = DoApp.DoApp()
  local voice = app.currentScore.flows[1].voiceStreams[1]
  local made = voice:createText(DoCore.RhythmicLength(0), DoCore.RhythmicLength(1), "E5\nC5")
  p:fact("made", tostring(made))
  local s = savedcopy.read(app, { dir = probe.runDir })
  local text = s.events[made.id]
  if p:check("the copy has the text", text ~= nil) then
    p:fact("words", text.words)
    p:fact("paragraphs", #text.paragraphs)
    p:check("one paragraph", #text.paragraphs == 1, #text.paragraphs)
    p:check("the words keep the newline", text.words == "E5\nC5", text.words)
  end
end)
