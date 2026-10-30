-- 06-match-by-event-id.lua matched every stream's dump to the saved copy with nothing left over, and showed one note
-- from both sides with the same id and spelling.
local checks = require("checks")

return function(p, run)
  local notes = 0
  for _, flow in ipairs(checks.expected().flows) do
    for _, player in ipairs(flow.players) do notes = notes + #player.notes end
  end
  local total, lua, file, streams = nil, nil, nil, 0
  for _, line in ipairs(run.printed) do
    local f = checks.fields(line)
    if f[1] == "stream" then streams = streams + 1 end
    if f[1] == "total" then total = f end
    if f[1] == "lua" then lua = f end
    if f[1] == "file" then file = f end
  end
  p:check("a line per stream", streams > 8, streams)
  p:check("the total line", total ~= nil)
  if total then
    p:check("every note matched, and more", tonumber(total[2]) >= notes, total[2] .. " matched, " .. notes .. " notes")
    p:check("nothing unmatched", total[3] == "0", total[3])
  end
  p:check("one note from both sides", lua and file and lua[2] == file[2], tostring(lua and lua[2]))
  if lua and file then
    p:check("the same spelling", lua[3]:find(" " .. file[4] .. " ", 1, true) ~= nil, lua[3] .. " / " .. file[4])
  end
end
