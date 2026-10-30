-- chord-symbols.lua named the piano's four chords, C, Am, F and G7 in bars 1 to 4, and put a chord symbol at the
-- start of each bar, in the first flow's timebase stream.
local checks = require("checks")

return function(p, run)
  local want = { "flow 1, bar 1: C", "flow 1, bar 2: Am", "flow 1, bar 3: F", "flow 1, bar 4: G7" }
  p:check("named the four chords", table.concat(run.printed, " / ") == table.concat(want, " / "),
    table.concat(run.printed, " / "))
  local symbols = checks.chordSymbols(1)
  p:fact("chordSymbols", symbols)
  p:check("a chord symbol at each", checks.joined(symbols) == checks.joined({ "0|C", "4|Am", "8|F", "12|G7" }),
    checks.joined(symbols))
  p:check("none in flow 2", #checks.chordSymbols(2) == 0)
  checks.musicUnchanged(p)
end
