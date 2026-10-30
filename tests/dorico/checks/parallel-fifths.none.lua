-- After parallel-fifths.lua was cancelled, undone, or asked only to remove its marks: no note has its colour, and the
-- two notes a user coloured keep theirs. args.cancelled: it also said it changed nothing.
local checks = require("checks")

return function(p, run, args)
  local want = checks.json("parallels.expected.json")
  if args.cancelled then p:check("said so", checks.printed(run, "Cancelled: nothing changed.")) end
  local users = {}
  for _, u in ipairs(want.userColours) do users[u.player .. "|" .. u.pos] = u.colour end
  local s, score, values = checks.savedCopy()
  local MARKED = 'string: "' .. want.mark .. '"'
  local wrong = {}
  for _, player in ipairs(s.players) do
    for _, e in ipairs(score.eventsOf(s, s.flows[1], player)) do
      if e.kind == "note" then
        local key = player.name .. "|" .. tostring(values.toNumber(e.position))
        for _, x in ipairs(score.entries(s, e)) do
          if x.property == "kEventColour" and x.value == MARKED then wrong[#wrong + 1] = key .. " is marked" end
        end
        if users[key] and score.value(s, e, "kEventColour", s.layouts[1].id) ~= users[key] then
          wrong[#wrong + 1] = key .. " lost its own colour"
        end
      end
    end
  end
  p:check("no marks, and the user's colours", #wrong == 0, table.concat(wrong, " / "))
end
