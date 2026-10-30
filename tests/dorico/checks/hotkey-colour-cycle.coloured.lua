-- Run with 04-read-the-saved-copy.lua at the end: the two selected violin notes have the cycle's first colour, set
-- again by the run after the pause, and no other note has a colour except the styled trumpet note.
local checks = require("checks")

return function(p, run)
  local styled = checks.expected().styled
  local coloured = {}
  for _, line in ipairs(run.printed) do
    local f = checks.fields(line)
    local isStyled = f[2] == styled.player and tonumber(f[3]) == styled.pos
    if #f == 6 and f[1] ~= "format" and f[6] ~= "-" and not isStyled then
      coloured[#coloured + 1] = table.concat({ f[2], f[3], f[4], f[6] }, "|")
    end
  end
  p:check("the two violin notes, and only they", checks.joined(coloured) == checks.joined({
    "Violin, solo & tutti|0|G4|#ffe41a1c", "Violin, solo & tutti|1|A4|#ffe41a1c" }), checks.joined(coloured))
end
