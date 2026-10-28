-- Makes the first player tacet in flow 1 before an example runs: deletes every event in the flute's voice there.
-- The violin's lyrics still keep stream.events from listing that flow. Scratch copy only (the probe confirms it).
local here = debug.getinfo(1, "S").source:match("^@(.*[/\\])")
local repo = here .. "../../"
local mine = here .. "lib/?.lua;" .. repo .. "spikes/lib/?.lua"
for name in pairs(package.loaded) do
  if package.searchpath(name, mine) then package.loaded[name] = nil end
end
if not package.path:find(mine, 1, true) then package.path = mine .. ";" .. package.path end
local probe = require("probe")

probe.run("case_tacet", function(p)
  local flow = DoApp.DoApp().currentScore.flows[1]
  flow.voiceStreams[1]:deleteEventsInRange(DoCore.RhythmicLength(0), DoCore.RhythmicLength(64))
  p:check("the flute's voice is empty", not flow.voiceStreams[1]:dump():find("kNoteEvent", 1, true))
end)
