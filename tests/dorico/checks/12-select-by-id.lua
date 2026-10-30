-- 12-select-by-id.lua coloured exactly the sample's notes above F5, said which, then how many it tried. Whether they
-- now have a colour is 12-select-by-id.coloured.lua's question: it runs 04 afterwards, which reads them from a saved
-- copy.
local checks = require("checks")

return function(p, run)
  local got = {}
  for i = 1, #run.printed - 1 do got[#got + 1] = table.concat(checks.fields(run.printed[i]), "|") end
  local want = checks.notesAbove("F5")
  p:check("five notes in the sample are above F5", #want == 5, checks.joined(want))
  p:check("printed exactly those", checks.joined(got) == checks.joined(want), checks.joined(got))
  local last = run.printed[#run.printed]
  p:check("then how many it tried", last == "Tried to colour 5 notes. Dorico doesn't report which took;"
    .. " 13-set-a-property-by-id.lua shows how to check.", last)
  checks.musicUnchanged(p)
end
