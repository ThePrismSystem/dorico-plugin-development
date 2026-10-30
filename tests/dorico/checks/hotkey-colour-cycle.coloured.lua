-- Run with 04-read-the-saved-copy.lua at the end: the two selected violin notes have the cycle's first colour, set
-- again by the run after the pause, and no other note has a colour except the styled trumpet note.
local checks = require("checks")

return function(p, run)
  local coloured = {}
  for _, note in ipairs(checks.noteLines(run)) do
    if note.colour ~= "-" and not checks.isStyled(note) then
      coloured[#coloured + 1] = table.concat({ note.player, note.pos, note.spelling, note.colour }, "|")
    end
  end
  p:check("the two violin notes, and only they", checks.joined(coloured) == checks.joined({
    "Violin, solo & tutti|0|G4|#ffe41a1c", "Violin, solo & tutti|1|A4|#ffe41a1c" }), checks.joined(coloured))
end
