-- 09-bars-keys-and-times.lua on the pickup fixture, an import of fixtures/pickup.musicxml: the one-beat pickup in 4/4
-- is bar 0, on beat 4, and the bars after it count from 1.
local checks = require("checks")

return function(p, run)
  local got = {}
  for _, line in ipairs(run.printed) do
    local f = checks.fields(line)
    if f[1] == "note" then got[#got + 1] = table.concat({ f[2], f[3], f[4], f[5], f[6] }, " ") end
  end
  local want = { "1 Flute 0 4 G4", "1 Flute 1 1 C5", "1 Flute 1 2 D5", "1 Flute 1 3 E5", "1 Flute 1 4 F5",
    "1 Flute 2 1 G5" }
  p:check("each note's bar and beat", checks.joined(got) == checks.joined(want), checks.joined(got))
  p:check("the time signature", checks.printed(run, "time\t1\t0\t4/4"), table.concat(run.printed, " / "))
end
