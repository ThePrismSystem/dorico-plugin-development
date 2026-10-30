-- After 13-set-a-property-by-id.lua and one Edit > Undo: no note has the blue, and the styled trumpet note has its
-- own colour back.
local checks = require("checks")

local BLUE = 'string: "#ff1f78b4"'

return function(p)
  local s, score, values = checks.savedCopy()
  local styled = checks.expected().styled
  local left = {}
  for key, e in pairs(checks.notesOf(s, score, values)) do
    for _, x in ipairs(score.entries(s, e)) do
      if x.property == "kEventColour" and x.value == BLUE then left[#left + 1] = key end
    end
    local owner = score.ownerOf(s, e)
    if owner.name == styled.player and values.toNumber(e.position) == styled.pos then
      p:check("the styled note's own colour", score.value(s, e, "kEventColour", s.layouts[1].id) == styled.colour)
    end
  end
  p:check("no note has the blue", #left == 0, table.concat(left, " / "))
end
