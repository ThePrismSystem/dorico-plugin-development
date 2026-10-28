-- proofread.lua found the sample's two planted problems, the flute's A3 below its range and the piano's parallel
-- fifths into bar 6, at the right bars and beats, and nothing else, and left no marker behind.
local checks = require("checks")

return function(p, run)
  local want = {
    "1 bar 2 beat 3: Flute plays A3, below its range (C4 to C7)",
    "1 bar 6 beat 1: Piano has parallel fifths between voices 1 and 3",
    "2 findings",
  }
  p:check("the two findings", table.concat(run.printed, " / ") == table.concat(want, " / "),
    table.concat(run.printed, " / "))
  p:check("no marker left", #checks.texts(1) == 0 and #checks.texts(2) == 0, checks.joined(checks.texts(1)))
  checks.musicUnchanged(p)
end
