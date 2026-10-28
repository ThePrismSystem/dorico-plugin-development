-- Read-only: the flow titles of the active project, from the text export.
local here = debug.getinfo(1, "S").source:match("^@(.*[/\\])")
local mine = here .. "?.lua;" .. here .. "lib/?.lua"
for name in pairs(package.loaded) do
  if package.searchpath(name, mine) then package.loaded[name] = nil end
end
if not package.path:find(mine, 1, true) then package.path = mine .. ";" .. package.path end
local probe = require("probe")

probe.run("flow_titles", function(p)
  local app = DoApp.DoApp()
  app:doCommand("File.Export.Text?File=" .. probe.runDir .. "flow-titles.txt&Show=false")
  local f = assert(io.open(probe.runDir .. "flow-titles.csv", "rb"))
  local titles = {}
  for line in f:read("*a"):gmatch("[^\r\n]+") do
    if line:find("Flow Info (Title)", 1, true) then titles[#titles + 1] = line end
  end
  f:close()
  p:fact("titles", titles)
end)
