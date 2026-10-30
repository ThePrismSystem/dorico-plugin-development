-- Run with 04-read-the-saved-copy.lua after 12-select-by-id.lua: the notes above F5 are red, the styled trumpet note
-- keeps its own colour unless it is one of them, and no other note has a colour. The command stores its colour for
-- the layout on screen, and that wins over a colour set with no context.
local checks = require("checks")

local RED = "#ffff0000"

return function(p, run)
  local styled = checks.expected().styled
  local above, wrong, notes = {}, {}, 0
  for _, key in ipairs(checks.notesAbove("F5")) do above[key] = true end
  for _, line in ipairs(run.printed) do
    local f = checks.fields(line)
    if #f == 6 and f[1] ~= "format" then
      notes = notes + 1
      local key = table.concat({ f[1], f[2], f[3], f[4] }, "|")
      local isStyled = f[2] == styled.player and tonumber(f[3]) == styled.pos
      local want = above[key] and RED or isStyled and styled.colour or "-"
      if f[6] ~= want then wrong[#wrong + 1] = line .. " (want " .. want .. ")" end
    end
  end
  p:check("04 read the notes", notes > 80, notes)
  p:check("every note has the colour it should", #wrong == 0, table.concat(wrong, " / "))
end
