-- S2: does Script.RunLastScript (Ctrl+Shift+Alt+R by default) run the last script again, and does a global survive
-- from one run to the next? Counts its own runs in a global. Read-only as far as the score goes.
local here = debug.getinfo(1, "S").source:match("^@(.*[/\\])")
local mine = here .. "?.lua;" .. here .. "lib/?.lua"
for name in pairs(package.loaded) do
  if package.searchpath(name, mine) then package.loaded[name] = nil end
end
if not package.path:find(mine, 1, true) then package.path = mine .. ";" .. package.path end
local probe = require("probe")

probe.run("s2_counter", function(p)
  EXAMPLES_S2_COUNT = (rawget(_G, "EXAMPLES_S2_COUNT") or 0) + 1
  p:fact("count", EXAMPLES_S2_COUNT)
  p:fact("clock", os.clock())
end)
