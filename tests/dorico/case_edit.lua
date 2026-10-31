-- Makes an edit of the user's own before an example runs: renames the second flow by command, in a run of its own,
-- so it's an undo step of its own. Scratch copy only (the probe confirms it).
local here = debug.getinfo(1, "S").source:match("^@(.*[/\\])")
local repo = here .. "../../"
local mine = here .. "lib/?.lua;" .. repo .. "spikes/lib/?.lua"
for name in pairs(package.loaded) do
  if package.searchpath(name, mine) then package.loaded[name] = nil end
end
if not package.path:find(mine, 1, true) then package.path = mine .. ";" .. package.path end
local probe = require("probe")

probe.run("case_edit", function()
  local app = DoApp.DoApp()
  app:doCommand(string.format("Project.Flow.Rename?FlowID=%d&Name=Edited before the run", app.currentScore.flows[2].id))
end, { scratchOnly = true })
