-- proofread.lua found the sample's planted problem, the flute's A3 below its advanced range, at the right bar and beat,
-- and nothing else, and changed nothing.
local checks = require("checks")

return function(p, run)
  local want = {
    "1 bar 2 beat 3: Flute plays A3, below its advanced range (B3 to D7)",
    "1 finding",
  }
  p:check("the finding", table.concat(run.printed, " / ") == table.concat(want, " / "),
    table.concat(run.printed, " / "))
  p:check("no text added", #checks.texts(1) == 0 and #checks.texts(2) == 0, checks.joined(checks.texts(1)))
  checks.musicUnchanged(p)
end
