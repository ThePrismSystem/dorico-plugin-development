-- What the text export says about the sample: a marker text in each voice stream, one export, the CSV kept as a fact,
-- and the markers deleted again. Scratch copy only (the probe confirms it).
local here = debug.getinfo(1, "S").source:match("^@(.*[/\\])")
local mine = here .. "?.lua;" .. here .. "lib/?.lua"
for name in pairs(package.loaded) do
  if package.searchpath(name, mine) then package.loaded[name] = nil end
end
if not package.path:find(mine, 1, true) then package.path = mine .. ";" .. package.path end
local probe = require("probe")

probe.run("export_names", function(p)
  local app = DoApp.DoApp()
  local score = app.currentScore
  p:fact("scoreTitle", tostring(score.title))
  local made = {}
  for fi, flow in ipairs(score.flows) do
    for si, s in ipairs(flow.voiceStreams) do
      local e = s:createText(DoCore.RhythmicLength(0), DoCore.RhythmicLength(1), "probe-marker-" .. fi .. "-" .. si)
      made[#made + 1] = { stream = s, event = e }
    end
  end
  local base = probe.runDir .. "export-names"
  os.remove(base .. ".csv")
  app:doCommand("File.Export.Text?File=" .. base .. ".txt&Show=false")
  for _, m in ipairs(made) do m.stream:delete(m.event) end
  local f = assert(io.open(base .. ".csv", "rb"))
  local csv = f:read("*a")
  f:close()
  local lines = {}
  for line in csv:gmatch("[^\n]+") do lines[#lines + 1] = line end
  p:fact("csv", lines)
  local left = 0
  for _, flow in ipairs(score.flows) do
    for _, s in ipairs(flow.voiceStreams) do
      if s:dump():find("probe-marker-", 1, true) then left = left + 1 end
    end
  end
  p:check("markers deleted", left == 0, left)
end)
