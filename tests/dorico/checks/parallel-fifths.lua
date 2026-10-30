-- After parallel-fifths.lua on the parallels fixture: it printed the findings worked out by hand (the sets
-- args.findings names, "default" if none), coloured the notes of each with its own colour in every layout, left the two
-- notes a user coloured with their own colours, and coloured nothing else.
local checks = require("checks")

return function(p, run, args)
  local want = checks.json("parallels.expected.json")
  local lines, marked = {}, {}
  for _, set in ipairs(args.findings or { "default" }) do
    for _, f in ipairs(want.findings[set]) do
      lines[#lines + 1] = string.format("%s\tflow 1\tbar %d, beat %g\t%s and %s", f.kind, math.floor(f.pos / 4) + 1,
        f.pos % 4 + 1, f.a, f.b)
      for _, who in ipairs({ f.a, f.b }) do
        marked[who .. "|" .. f.pos] = true
        marked[who .. "|" .. (f.pos - 1)] = true
      end
    end
  end
  local got = {}
  for _, line in ipairs(run.printed) do
    if line:find("\tflow ", 1, true) then got[#got + 1] = line end
  end
  p:check("the findings", checks.joined(got) == checks.joined(lines),
    "got " .. checks.joined(got) .. " | want " .. checks.joined(lines))

  local users = {}
  for _, u in ipairs(want.userColours) do users[u.player .. "|" .. u.pos] = u.colour end
  local s, score, values = checks.savedCopy()
  local MARKED = 'string: "' .. want.mark .. '"'
  local wrong = {}
  for _, player in ipairs(s.players) do
    for _, e in ipairs(score.eventsOf(s, s.flows[1], player)) do
      if e.kind == "note" then
        local key = player.name .. "|" .. tostring(values.toNumber(e.position))
        local mark = false
        for _, x in ipairs(score.entries(s, e)) do
          if x.property == "kEventColour" and x.value == MARKED then mark = x.layout == -1 and x.instance == -1 end
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
