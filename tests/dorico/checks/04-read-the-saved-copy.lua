-- 04-read-the-saved-copy.lua read the sample's format, found the trumpet's styled note with its notehead and colour,
-- and read every other note as plain.
local checks = require("checks")

return function(p, run)
  local want = checks.expected()
  local styled = want.styled
  local got, found, plain, others, format = {}, 0, 0, 0, nil
  for _, line in ipairs(run.printed) do
    local f = checks.fields(line)
    if f[1] == "format" then
      format = f
    elseif #f == 6 then
      got[#got + 1] = table.concat({ f[1], f[2], f[3], f[4] }, "|")
      if f[2] == styled.player and tonumber(f[3]) == styled.pos then
        found = found + 1
        p:check("the styled note's notehead", f[5] == styled.notehead, f[5])
        p:check("the styled note's colour", f[6] == styled.colour, f[6])
      elseif f[5] == "-" and f[6] == "-" then
        plain = plain + 1
      else
        others = others + 1
        p:check("no other note is styled", false, line)
      end
    end
  end
  p:check("the format line", format and format[2]:match("^1%.%d+$") and format[3] == "known",
    format and table.concat(format, " "))
  p:check("the styled note was found once", found == 1, found)

  local keys = {}
  for n, flow in ipairs(want.flows) do
    for _, player in ipairs(flow.players) do
      for _, note in ipairs(player.notes) do
        keys[#keys + 1] = table.concat({ n, player.name, tostring(note.pos), note.spelling }, "|")
      end
    end
  end
  p:check("every note, at its position", checks.joined(got) == checks.joined(keys),
    "got " .. checks.joined(got) .. " | want " .. checks.joined(keys))
  p:check("every other note is plain", plain == #keys - 1 and others == 0, plain .. " plain, " .. others .. " other")
end
