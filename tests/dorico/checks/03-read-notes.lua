-- 03-read-notes.lua printed exactly the sample's notes, flow by flow and player by player. The violin's voice holds
-- lyrics, so stream.events can't list it: the notes can only have come from the dump.
local checks = require("checks")

local function key(spelling, pos, duration, grace)
  return table.concat({ spelling, tostring(pos), grace and "" or tostring(duration), grace and "g" or "n" }, "|")
end

return function(p, run)
  local want = checks.expected()
  local got, total = {}, 0
  for _, line in ipairs(run.printed) do
    local f = checks.fields(line)
    if #f == 6 then
      local grace = f[5] == "grace"
      local at = f[1] .. "|" .. f[2]
      got[at] = got[at] or {}
      table.insert(got[at], key(f[6], tonumber(f[4]), tonumber(f[5]), grace))
    end
  end

  for n, flow in ipairs(want.flows) do
    for _, player in ipairs(flow.players) do
      local keys = {}
      for i, note in ipairs(player.notes) do keys[i] = key(note.spelling, note.pos, note.duration, note.grace) end
      total = total + #keys
      local mine = got[n .. "|" .. player.name] or {}
      p:check("flow " .. n .. " " .. player.name, checks.joined(mine) == checks.joined(keys),
        "got " .. checks.joined(mine) .. " | want " .. checks.joined(keys))
    end
  end
  p:check("the count line", run.printed[#run.printed] == total .. " notes", run.printed[#run.printed])

  local score = DoApp.DoApp().currentScore
  local violinId = score.players[3].instruments[1].id
  local flow = score.flows[1]
  for i, stream in ipairs(flow.voiceStreams) do
    if flow.instruments[i].id == violinId then
      p:check("stream.events fails on the violin's voice", not pcall(function() return stream.events end))
    end
  end
end
