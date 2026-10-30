-- label-notes.lua wrote one valve label at each of the trumpet's notes, for its written pitch a tone above the
-- sounding one, and no other text.
local checks = require("checks")

-- The trumpet's notes in the sample, sounding, by position, with the valves for each written note (a tone higher).
local WANT = {
  "0|12", "1|12", "2|2", "3|12", "4|1", "6|0", "8|2", "12|0", "13|1", "14|12", "15|1", "16|12", "20|2", "21|0",
  "22|12", "23|2", "24|12", "28|1",
}

return function(p, run)
  p:check("said how many", run.printed[1] == #WANT .. " labels written", run.printed[1])
  local got = checks.texts(1)
  p:check("a label at each trumpet note", checks.joined(got) == checks.joined(WANT), checks.joined(got))
  p:check("nothing in flow 2", #checks.texts(2) == 0, checks.joined(checks.texts(2)))
  checks.musicUnchanged(p)
end
