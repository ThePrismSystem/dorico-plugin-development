-- S6: where does print() go when a script runs from the Script menu? Prints three marked lines; the driver
-- (spikes/s6_print.py) captures Dorico's windows to see whether the Script Console shows them.
local here = debug.getinfo(1, "S").source:match("^@(.*[/\\])")
local mine = here .. "?.lua;" .. here .. "lib/?.lua"
for name in pairs(package.loaded) do
  if package.searchpath(name, mine) then package.loaded[name] = nil end
end
if not package.path:find(mine, 1, true) then package.path = mine .. ";" .. package.path end
local probe = require("probe")

probe.run("s6_print", function(p)
  for i = 1, 3 do print("S6 print line " .. i) end
  io.write("S6 io.write line\n")
  p:fact("printIs", tostring(print))
  p:fact("ioOutput", tostring(io.output()))
end)
