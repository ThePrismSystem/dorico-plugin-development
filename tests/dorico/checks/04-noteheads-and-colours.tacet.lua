-- 04-noteheads-and-colours.lua with the flute tacet in flow 1 (case_tacet.lua emptied its voice): every note it reads
-- is named for the player who plays it, the styled trumpet note included, and no flute note appears in flow 1.
local checks = require("checks")

return function(p, run)
  local want = checks.expected()
  local styled = want.styled
  local got, styledFound = {}, false
  for _, line in ipairs(run.printed) do
    local f = checks.fields(line)
    if #f == 6 then
      got[#got + 1] = table.concat({ f[1], f[2], f[3], f[4] }, "|")
      if f[2] == styled.player and tonumber(f[3]) == styled.pos and f[5] == styled.notehead then styledFound = true end
    end
  end
  local keys = {}
  for n, flow in ipairs(want.flows) do
    for _, player in ipairs(flow.players) do
      if not (n == 1 and player.name == "Flute") then
        for _, note in ipairs(player.notes) do
          keys[#keys + 1] = table.concat({ n, player.name, tostring(note.pos), note.spelling }, "|")
        end
      end
    end
  end
  p:check("every note under its own player", checks.joined(got) == checks.joined(keys),
    "got " .. checks.joined(got):sub(1, 1500))
  p:check("the styled trumpet note found as the trumpet's", styledFound)
end
