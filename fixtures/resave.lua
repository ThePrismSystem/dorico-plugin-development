-- Saves the scratch copy tools/resave_fixtures.py has open to args.out, in the running Dorico's format.
local here = debug.getinfo(1, "S").source:match("^@(.*[/\\])")
local mine = here .. "?.lua;" .. here .. "../spikes/lib/?.lua"
for name in pairs(package.loaded) do
  if package.searchpath(name, mine) then package.loaded[name] = nil end
end
if not package.path:find(mine, 1, true) then package.path = mine .. ";" .. package.path end
local probe = require("probe")

probe.run("resave", function(p)
  local app = DoApp.DoApp()
  os.remove(p.args.out)
  p:check("saved", app:save(app.currentScore, p.args.out) == true, p.args.out)
end)
