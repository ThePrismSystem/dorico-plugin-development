-- Finishes the imported sample on its scratch copy: adds a second flow with four flute notes. MusicXML holds one
-- flow, so the second is made here. fixtures/build_sample.py runs it.
local here = debug.getinfo(1, "S").source:match("^@(.*[/\\])")
local mine = here .. "?.lua;" .. here .. "../spikes/lib/?.lua"
for name in pairs(package.loaded) do
  if package.searchpath(name, mine) then package.loaded[name] = nil end
end
if not package.path:find(mine, 1, true) then package.path = mine .. ";" .. package.path end
local probe = require("probe")

local SECOND_FLOW = "Second movement"
local SECOND_FLOW_FLUTE = { "C5", "D5", "E5", "F5" }

probe.run("finish_sample", function(p)
  local app = DoApp.DoApp()
  local score = app.currentScore
  local before = {}
  for _, f in ipairs(score.flows) do before[f.id] = true end
  app:doCommand("Project.Flow.New")
  local second
  for _, f in ipairs(app.currentScore.flows) do
    if not before[f.id] then second = f end
  end
  if not p:check("a second flow was added", second ~= nil) then return end
  app:doCommand(string.format("Project.Flow.Rename?FlowID=%d&Name=%s", second.id, SECOND_FLOW))
  local fluteId = app.currentScore.players[1].instruments[1].id
  local flute
  for i, s in ipairs(second.voiceStreams) do
    if not flute and second.instruments[i].id == fluteId then flute = s end
  end
  if p:check("the second flow has a flute voice", flute ~= nil) then
    for i, spelling in ipairs(SECOND_FLOW_FLUTE) do
      flute:createNote(DoCore.RhythmicLength(i - 1), DoCore.RhythmicLength(1),
        DoCore.MIDIPitchWithSpelling.fromString(spelling))
    end
  end
  p:fact("flows", #app.currentScore.flows)
end)
