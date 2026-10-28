-- 07-act-on-the-selection.lua found the two violin notes the driver selected (G4 and A4, the first two), labelled
-- each, and left every note's pitch as it was after its semitone up and back.
local checks = require("checks")

return function(p, run)
  local want = { "1\tViolin, solo & tutti\t0\tG4", "1\tViolin, solo & tutti\t1\tA4" }
  p:check("printed the two selected notes", table.concat(run.printed, " / ") == table.concat(want, " / "),
    table.concat(run.printed, " / "))
  p:check("a label at each, and no other text", checks.joined(checks.texts(1)) == checks.joined({ "0|G4", "1|A4" }),
    checks.joined(checks.texts(1)))
  checks.musicUnchanged(p)
end
