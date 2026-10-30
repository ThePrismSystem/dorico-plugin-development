-- After cautionary-accidentals.lua was cancelled, undone, or asked only to take back: no note has an accidental
-- visibility with no layout of its own, and the user's bracket stays. args.cancelled: it also said it changed nothing;
-- args.takenBack: it said how many it took back.
local checks = require("checks")

local PROPERTY = "kNoteAccidentalVisibility_v3"

return function(p, run, args)
  local want = checks.json("cautionary.expected.json")
  if args.cancelled then p:check("said so", checks.printed(run, "Cancelled: nothing changed.")) end
  if args.takenBack then
    local line = string.format("Took back %d cautionary accidentals.", args.takenBack)
    p:check("said how many", checks.printed(run, line), line)
  end
  local s, score, values = checks.savedCopy()
  local user = want.userBracket
  local wrong, kept = {}, false
  for _, player in ipairs(s.players) do
    for _, e in ipairs(score.eventsOf(s, s.flows[1], player)) do
      if e.kind == "note" then
        for _, x in ipairs(score.entries(s, e)) do
          if x.property == PROPERTY then
            local v = values.typed(x.value).value
            if x.layout == -1 and x.instance == -1 then
              wrong[#wrong + 1] = player.name .. "|" .. tostring(values.toNumber(e.position)) .. " is marked " .. v
            elseif player.name == user.player and values.toNumber(e.position) == user.pos and v == user.value then
              kept = true
            end
          end
        end
      end
    end
  end
  p:check("no marks", #wrong == 0, table.concat(wrong, " / "))
  p:check("the user's bracket stays", kept)
end
