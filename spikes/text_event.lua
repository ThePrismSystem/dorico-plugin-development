-- Spike: what TextEvent.text gives, and whether a script can set it. On a scratch copy of the sample, creates a text
-- in the first voice whose events Lua can list, reads it back, and tries to set its text.
--   python tools/run_lua.py spikes/text_event.lua --open fixtures/6.2.30/sample.dorico
local here = debug.getinfo(1, "S").source:match("^@(.*[/\\])")
local mine = here .. "lib/?.lua"
for name in pairs(package.loaded) do
  if package.searchpath(name, mine) then package.loaded[name] = nil end
end
if not package.path:find(mine, 1, true) then package.path = mine .. ";" .. package.path end
local probe = require("probe")

local WORDS = "probe words, with a comma & an ampersand"

probe.run("text_event", function(p)
  local app = DoApp.DoApp()
  local RL = DoCore.RhythmicLength
  local voice
  for _, flow in ipairs(app.currentScore.flows) do
    for _, stream in ipairs(flow.voiceStreams) do
      if not voice and pcall(function() return stream.events end) then voice = stream end
    end
  end
  if not p:check("a voice whose events Lua can list", voice ~= nil) then return end
  local made = voice:createText(RL(0), RL(1), WORDS)
  p:fact("created", tostring(made))
  local text, seen = nil, {}
  for _, ev in ipairs(voice.events) do
    seen[#seen + 1] = tostring(ev)
    if tostring(ev):find("kTextEvent", 1, true) then text = ev end
  end
  p:fact("events", seen)
  p:fact("dump", voice:dump())
  if not text and made then text = made end
  if not p:check("the text is listed", text ~= nil) then return end
  p:fact("class", tostring(getmetatable(text) and getmetatable(text).__name))
  local ok, words = pcall(function() return text.text end)
  p:fact("read", { ok = ok, value = tostring(words), type = type(words) })
  p:check("text reads the words", ok and tostring(words) == WORDS, tostring(words))
  local setOk, err = pcall(function() text.text = "changed" end)
  p:fact("set", { ok = setOk, err = tostring(err) })
  local after = pcall(function() return text.text end) and tostring(text.text)
  p:fact("after", after)
  p:check("setting text fails", not setOk, tostring(err))
end)
