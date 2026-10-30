-- After 13-set-a-property-by-id.lua: a saved copy shows the blue on every note above F5 and on nothing else, stored
-- with no context, so the player's part shows it too.
local checks = require("checks")

local BLUE = "#ff1f78b4"

return function(p, run)
  local s, score, values = checks.savedCopy()
  local above = {}
  for _, key in ipairs(checks.notesAbove("F5")) do above[key] = true end
  local wrong, coloured = {}, 0
  for key, e in pairs(checks.notesOf(s, score, values)) do
    local stored = false
    for _, x in ipairs(score.entries(s, e)) do
      if x.property == "kEventColour" and x.value == 'string: "' .. BLUE .. '"' then
        stored = x.layout == -1 and x.instance == -1
      end
    end
    if above[key] then
      coloured = coloured + 1
      local part = score.partOf(s, score.ownerOf(s, e))
      if not stored or score.value(s, e, "kEventColour", part.id) ~= BLUE then wrong[#wrong + 1] = key end
    elseif stored then
      wrong[#wrong + 1] = key .. " (not above F5)"
    end
  end
  p:check("the notes above F5 were found", coloured > 0 and coloured == #checks.notesAbove("F5"), coloured)
  p:check("each has the blue in every layout, and no other note has it", #wrong == 0, table.concat(wrong, " / "))
  p:check("a line per note", #run.printed == coloured, #run.printed)
end
