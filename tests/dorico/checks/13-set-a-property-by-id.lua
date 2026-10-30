-- After 13-set-a-property-by-id.lua: a saved copy shows the blue on every note above F5 and on nothing else, stored
-- with no context, so the player's part shows it too. The script printed a line for each of those notes, saying it
-- took, and a total.
local checks = require("checks")

local BLUE = "#ff1f78b4"

return function(p, run)
  local s, score, values = checks.savedCopy()
  local wanted = checks.notesAbove("F5")
  local above = {}
  for _, key in ipairs(wanted) do above[key] = true end
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
  p:check("the notes above F5 were found", coloured > 0 and coloured == #wanted, coloured)
  p:check("each has the blue in every layout, and no other note has it", #wrong == 0, table.concat(wrong, " / "))

  local lines, took = {}, 0
  for i = 1, #run.printed - 1 do
    local f = checks.fields(run.printed[i])
    lines[#lines + 1] = table.concat({ f[1], f[2], f[3], f[4] }, "|")
    if f[5] == "coloured" then took = took + 1 end
  end
  p:check("a line per note it set", checks.joined(lines) == checks.joined(wanted), checks.joined(lines))
  p:check("each line says it took", took == #wanted, took)
  p:check("the total line", run.printed[#run.printed] == table.concat({ "total", #wanted, #wanted }, "\t"),
    run.printed[#run.printed])
end
