-- After note-names.lua named one player's notes at a time: the players args.players lists have one name at each chord
-- and no other player has any, so a run for one player left the names an earlier run gave another. The run removed
-- no old names.
local checks = require("checks")

return function(p, run, args)
  local s, score, values = checks.savedCopy()
  local own, named, seen = {}, {}, {}
  for _, want in ipairs(checks.reading().texts) do own[want.words] = true end
  for _, name in ipairs(args.players) do named[name] = true end
  local wrong = {}
  for _, flow in ipairs(s.flows) do
    for _, stream in ipairs(flow.streams) do
      if stream.type == "voice" then
        local player = score.ownerOf(s, stream.events[1] or { flowId = flow.id, streamId = stream.id }) or {}
        local chords, texts = {}, {}
        for _, e in ipairs(stream.events) do
          local k = values.positionText(e.position)
          if e.kind == "note" then chords[k] = true end
          if e.kind == "text" and not own[e.words] then texts[k] = (texts[k] or 0) + 1 end
        end
        for k in pairs(chords) do
          local want = named[player.name] and 1 or 0
          if (texts[k] or 0) ~= want then
            wrong[#wrong + 1] = tostring(player.name) .. "@" .. k .. " has " .. (texts[k] or 0)
          end
          if want == 1 then seen[player.name] = true end
        end
      end
    end
  end
  for _, name in ipairs(args.players) do
    if not seen[name] then wrong[#wrong + 1] = name .. " has no notes" end
  end
  p:check("names on " .. table.concat(args.players, " and ") .. " only", #wrong == 0, table.concat(wrong, " / "))
  p:check("removed none", run.printed[#run.printed]:find("removed 0 old ones", 1, true) ~= nil,
    run.printed[#run.printed])
end
