-- chord-symbols.lua with a "D" already at the start of flow 1 (case_chord.lua put it there): the recipe leaves that
-- one alone, says so, and adds the other three.
local checks = require("checks")

return function(p, run)
  local want = { "flow 1, bar 1: C (a chord symbol is already there, left as it is)", "flow 1, bar 2: Am",
    "flow 1, bar 3: F", "flow 1, bar 4: G7" }
  p:check("said what it did", table.concat(run.printed, " / ") == table.concat(want, " / "),
    table.concat(run.printed, " / "))
  local symbols = checks.chordSymbols(1)
  p:check("the D kept, the rest added", checks.joined(symbols) == checks.joined({ "0|D", "4|Am", "8|F", "12|G7" }),
    checks.joined(symbols))
end
