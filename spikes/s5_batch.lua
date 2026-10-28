-- S5: can a script open other projects, change them, save and close them? For each path in args.paths (copies in
-- the run folder only): File.Open, rename its first flow, File.Save, File.CloseProject. Also lists what
-- DoCore.ScriptHost offers, without calling any of it. Runs from a scratch copy.
local here = debug.getinfo(1, "S").source:match("^@(.*[/\\])")
local mine = here .. "?.lua;" .. here .. "lib/?.lua"
for name in pairs(package.loaded) do
  if package.searchpath(name, mine) then package.loaded[name] = nil end
end
if not package.path:find(mine, 1, true) then package.path = mine .. ";" .. package.path end
local probe = require("probe")

probe.run("s5_batch", function(p)
  local app = DoApp.DoApp()
  local startId = app.currentScore.openScoreID
  local steps = {}
  for _, path in ipairs(p.args.paths or {}) do
    if path:sub(1, #probe.runDir) ~= probe.runDir then error("refusing a path outside the run folder: " .. path) end
    app:doCommand("File.Open?File=" .. path)
    local score = app.currentScore
    local id = score and score.openScoreID
    local entry = { path = path, openScoreID = id, same = id == startId }
    if id and id ~= startId then
      app:doCommand(string.format("Project.Flow.Rename?FlowID=%d&Name=Batched", score.flows[1].id))
      app:doCommand("File.Save")
      app:doCommand(string.format("File.CloseProject?OpenScoreID=%d&Save=false", id))
      entry.afterClose = app.currentScore and app.currentScore.openScoreID
    end
    steps[#steps + 1] = entry
  end
  p:fact("steps", steps)
  local host = {}
  for _, name in ipairs({ "currentScore", "engine", "save", "showFolderChooser", "convertFolderOfScores",
    "createNewScore" }) do
    local ok, v = pcall(function() return DoCore.ScriptHost[name] end)
    host[name] = ok and type(v) or ("error: " .. tostring(v):sub(1, 80))
  end
  p:fact("scriptHost", host)
end)
