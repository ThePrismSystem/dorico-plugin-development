-- Runs one example as the Script menu would, with print recorded, then a check script that looks at what it did.
-- Scratch copy only (the probe confirms it).
--   args.example, args.check: paths from the repository root
--   args.twice: run the example a second time first, as a user might, in Dorico's one Lua state
-- A check file returns function(p, run, args), where run = {printed, ok, err, second}.
local here = debug.getinfo(1, "S").source:match("^@(.*[/\\])")
local repo = here .. "../../"
local mine = here .. "lib/?.lua;" .. repo .. "spikes/lib/?.lua;" .. repo .. "fixtures/?.lua"
for name in pairs(package.loaded) do
  if package.searchpath(name, mine) then package.loaded[name] = nil end
end
if not package.path:find(mine, 1, true) then package.path = mine .. ";" .. package.path end
local probe = require("probe")

local function runExample(path)
  local printed, realPrint = {}, print
  print = function(...)
    local parts = {}
    for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
    printed[#printed + 1] = table.concat(parts, "\t")
  end
  local ok, err = pcall(dofile, path)
  print = realPrint
  return { printed = printed, ok = ok, err = (not ok) and tostring(err) or nil }
end

probe.run("case_example", function(p)
  local first = runExample(repo .. p.args.example)
  local run = first
  if p.args.twice then
    run = runExample(repo .. p.args.example)
    run.first = first
  end
  p:fact("printed", run.printed)
  p:check("the example ran without an error", run.ok, run.err)
  if run.first then
    p:check("a second run prints the same as the first", table.concat(run.printed, "\n")
      == table.concat(first.printed, "\n"), table.concat(first.printed, " / "))
  end
  local check = assert(loadfile(repo .. p.args.check))()
  check(p, run, p.args)
end)
