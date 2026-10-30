-- Sets one note's property through the Properties panel's route, on the scratch copy fixtures/build_reading.py has
-- open with a part on screen, so Dorico stores the value for that part's layout only. Args: flowId, eventId,
-- blockId, property, value.
local here = debug.getinfo(1, "S").source:match("^@(.*[/\\])")
local mine = here .. "?.lua;" .. here .. "../spikes/lib/?.lua"
for name in pairs(package.loaded) do
  if package.searchpath(name, mine) then package.loaded[name] = nil end
end
if not package.path:find(mine, 1, true) then package.path = mine .. ";" .. package.path end
local probe = require("probe")

probe.run("colour_in_part", function(p)
  local a = p.args
  local app = DoApp.DoApp()
  app:doCommand("Edit.SelectNone")
  app:doCommand(string.format("EventEdit.Select?FlowID=%d&EventID=%d&EventBlockID=%d", a.flowId, a.eventId,
    a.blockId))
  app:doCommand(string.format("UI.InvokePropertyChangeValue?Type=%s&Value=%s", a.property, a.value))
  app:doCommand("Edit.SelectNone")
  p:fact("set", a.property .. "=" .. a.value)
end)
