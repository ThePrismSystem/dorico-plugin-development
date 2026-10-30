-- 12-select-by-id.lua coloured exactly the sample's notes above F5, and said which. Whether they now have a colour
-- is 12-select-by-id.coloured.lua's question: it runs 04 afterwards, which reads them from a saved copy.
local checks = require("checks")

return function(p, run)
  local got = {}
  for _, line in ipairs(run.printed) do got[#got + 1] = table.concat(checks.fields(line), "|") end
  local want = checks.notesAbove("F5")
  p:check("five notes in the sample are above F5", #want == 5, checks.joined(want))
  p:check("printed exactly those", checks.joined(got) == checks.joined(want), checks.joined(got))
  checks.musicUnchanged(p)
end
