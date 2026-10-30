-- After cautionary-accidentals.lua on the cautionary fixture: it printed the findings worked out by hand (the set
-- args.findings names, "default" if none), gave exactly those notes the accidental visibility args.value
-- (kRoundBrackets if none) with no layout of their own, and left the user's bracket as it was. args.kept: the run
-- found them all marked already, by an earlier run with the same brackets; args.takenBack: how many marks it took off.
local checks = require("checks")

local PROPERTY = "kNoteAccidentalVisibility_v3"

return function(p, run, args)
  local want = checks.json("cautionary.expected.json")
  local findings = want.findings[args.findings or "default"]
  local lines, marked = {}, {}
  for _, f in ipairs(findings) do
    lines[#lines + 1] = string.format("%s\tflow 1\tbar %d, beat %g\t%s, after %s", f.player, f.bar, f.beat,
      f.spelling, f.after)
    marked[f.player .. "|" .. (4 * (f.bar - 1) + f.beat - 1)] = true
  end
  local got = {}
  for _, line in ipairs(run.printed) do
    if line:find("\tflow ", 1, true) then got[#got + 1] = line end
  end
  p:check("the findings", checks.joined(got) == checks.joined(lines),
    "got " .. checks.joined(got) .. " | want " .. checks.joined(lines))
  local summary = string.format("Added %d cautionary accidentals, kept %d from an earlier run, took back %d.",
    args.kept and 0 or #findings, args.kept and #findings or 0, args.takenBack or 0)
  p:check("the summary", checks.printed(run, summary), summary)

  local s, score, values = checks.savedCopy()
  local value = args.value or "kRoundBrackets"
  local user = want.userBracket
  local wrong = {}
  for _, player in ipairs(s.players) do
    for _, e in ipairs(score.eventsOf(s, s.flows[1], player)) do
      if e.kind == "note" then
        local key = player.name .. "|" .. tostring(values.toNumber(e.position))
        local mark, layoutValue
        for _, x in ipairs(score.entries(s, e)) do
          if x.property == PROPERTY then
            local v = values.typed(x.value).value
            if x.layout == -1 and x.instance == -1 then mark = v else layoutValue = v end
          end
        end
        if marked[key] then
          if mark ~= value then wrong[#wrong + 1] = key .. " has " .. tostring(mark) end
        elseif mark then
          wrong[#wrong + 1] = key .. " is marked " .. mark
        end
        local isUser = player.name == user.player and values.toNumber(e.position) == user.pos
        if isUser and layoutValue ~= user.value then wrong[#wrong + 1] = key .. " lost the user's bracket" end
        if not isUser and layoutValue then wrong[#wrong + 1] = key .. " has a layout value" end
      end
    end
  end
  p:check("exactly the findings' notes are marked, and the user's bracket stays", #wrong == 0,
    table.concat(wrong, " / "))
end
