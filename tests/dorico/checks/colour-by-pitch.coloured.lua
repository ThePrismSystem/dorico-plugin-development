-- Run with 04-noteheads-and-colours.lua after colour-by-pitch.lua: every note has a colour. A colour set by command
-- reads as "(unreadable)", so which colour can't be checked from Lua. The styled trumpet note is the exception: its
-- colour was set through its property table, and that keeps reading back after the command, though the page shows
-- the command's colour (seen on a screenshot of this test's copy).
local checks = require("checks")

return function(p, run)
  local styled = checks.expected().styled
  local plain, notes = {}, 0
  for _, line in ipairs(run.printed) do
    local f = checks.fields(line)
    if #f == 6 then
      notes = notes + 1
      local isStyled = f[2] == styled.player and tonumber(f[3]) == styled.pos
      if f[6] ~= "(unreadable)" and not (isStyled and f[6] == styled.colour) then plain[#plain + 1] = line end
    end
  end
  p:check("04 read every note", notes > 80, notes)
  p:check("every note has a colour set by command", #plain == 0, table.concat(plain, " / "))
end
