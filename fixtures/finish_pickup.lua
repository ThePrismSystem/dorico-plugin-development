-- Checks the imported pickup fixture on its scratch copy before fixtures/build_pickup.py saves it: one flow, whose
-- first note is the one-beat pickup, a G4 at 0.
local here = debug.getinfo(1, "S").source:match("^@(.*[/\\])")
local mine = here .. "?.lua;" .. here .. "../spikes/lib/?.lua"
for name in pairs(package.loaded) do
  if package.searchpath(name, mine) then package.loaded[name] = nil end
end
if not package.path:find(mine, 1, true) then package.path = mine .. ";" .. package.path end
local probe = require("probe")

probe.run("finish_pickup", function(p)
  local score = DoApp.DoApp().currentScore
  p:check("one flow", #score.flows == 1, #score.flows)
  local dump = score.flows[1].voiceStreams[1]:dump()
  p:check("the pickup note at 0", dump:find("kNoteEvent %(id:%d+%) at 0, duration 1  G4") ~= nil, dump:sub(1, 300))
end)
