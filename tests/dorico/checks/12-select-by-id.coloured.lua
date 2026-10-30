-- Run with 04-noteheads-and-colours.lua after 12-select-by-id.lua: the notes above F5 have a colour (one set by
-- command reads as "(unreadable)"), the styled trumpet note keeps its own, and no other note has one.
local checks = require("checks")

return function(p, run)
  local styled = checks.expected().styled
  local coloured = {}
  for _, line in ipairs(run.printed) do
    local f = checks.fields(line)
    local isStyled = f[2] == styled.player and tonumber(f[3]) == styled.pos
    if isStyled then
      p:check("the styled note keeps its colour", f[6] == styled.colour, f[6])
    elseif f[6] ~= "-" then
      coloured[#coloured + 1] = table.concat({ f[1], f[2], f[3], f[4] }, "|")
      p:check("a command-set colour can't be read", f[6] == "(unreadable)", line)
    end
  end
  p:check("exactly the notes above F5 have a colour", checks.joined(coloured) == checks.joined(checks.notesAbove("F5")),
    checks.joined(coloured))
end
