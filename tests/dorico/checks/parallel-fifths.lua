-- After parallel-fifths.lua on the parallels fixture: it printed the findings worked out by hand (the sets
-- args.findings names, "default" if none), coloured the notes of each with its own colour in every layout, left the two
-- notes a user coloured with their own colours, and coloured nothing else. Its summary counts them, and the marks it
-- took off, which are those of the sets args.before names, from the run before it on the same copy.
local checks = require("checks")

return function(p, run, args)
  local want = checks.json("parallels.expected.json")
  local lines, marked, kept = checks.parallels(args.findings or { "default" })
  local got = {}
  for _, line in ipairs(run.printed) do
    if line:find("\tflow ", 1, true) then got[#got + 1] = line end
  end
  p:check("the findings", checks.joined(got) == checks.joined(lines),
    "got " .. checks.joined(got) .. " | want " .. checks.joined(lines))
  local _, before = checks.parallels(args.before or {})
  local summary = string.format("%d found; %d notes coloured, %d kept their own colour; %d old marks taken off.",
    #lines, checks.count(marked), checks.count(kept), checks.count(before))
  p:check("the summary", checks.printed(run, summary), summary .. " | " .. table.concat(run.printed, " / "))

  local users = {}
  for _, u in ipairs(want.userColours) do users[u.player .. "|" .. u.pos] = u.colour end
  local s, score, values = checks.savedCopy()
  local wrong = {}
  for _, player in ipairs(s.players) do
    for _, e in ipairs(score.eventsOf(s, s.flows[1], player)) do
      if e.kind == "note" then
        local key = player.name .. "|" .. tostring(values.toNumber(e.position))
        local mark = false
        for _, x in ipairs(score.entries(s, e)) do
          if x.property == "kEventColour" and values.typed(x.value).value == want.mark then
            mark = x.layout == -1 and x.instance == -1
          end
        end
        if users[key] then
          if mark or score.value(s, e, "kEventColour", s.layouts[1].id) ~= users[key] then
            wrong[#wrong + 1] = key .. " lost its own colour"
          end
        elseif mark ~= (marked[key] == true) then
          wrong[#wrong + 1] = key .. (mark and " is marked" or " isn't marked")
        end
      end
    end
  end
  p:check("exactly the findings' notes are marked, in every layout", #wrong == 0, table.concat(wrong, " / "))
end
