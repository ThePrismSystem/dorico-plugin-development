-- Run with 04-read-the-saved-copy.lua after 12-select-by-id.lua and one Edit > Undo: every colour the script set
-- is gone, and the styled trumpet note still has its own.
local checks = require("checks")

return function(p, run)
  local styled = checks.expected().styled
  local others = {}
  for _, line in ipairs(run.printed) do
    local f = checks.fields(line)
    if #f == 6 and f[1] ~= "format" then
      if f[2] == styled.player and tonumber(f[3]) == styled.pos then
        p:check("the styled note keeps its colour", f[6] == styled.colour, f[6])
      elseif f[6] ~= "-" then
        others[#others + 1] = line
      end
    end
  end
  p:check("no other note has a colour", #others == 0, table.concat(others, " / "))
end
