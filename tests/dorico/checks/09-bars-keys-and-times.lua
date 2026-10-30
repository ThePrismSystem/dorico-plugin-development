-- 09-bars-keys-and-times.lua printed the reading fixture's key and time signatures, and the bar and beat of each of
-- the flute's notes: bars of 4/4 up to beat 24, then 3/4.
local checks = require("checks")

local function number(text)
  local a, b = text:match("^(%d+)/(%d+)$")
  return a and tonumber(a) / tonumber(b) or tonumber(text)
end

return function(p, run)
  local want = checks.reading()
  for _, k in ipairs(want.keys) do
    p:check("key at " .. k.pos, checks.printed(run, table.concat({ "key", k.flow, k.pos, k.fifths, "major" }, "\t")))
  end
  for _, x in ipairs(want.times) do
    p:check("time at " .. x.pos,
      checks.printed(run, table.concat({ "time", x.flow, x.pos, x.beats .. "/" .. x.beatType }, "\t")))
  end
  local function key(bar, beat, spelling) return string.format("%d|%.6f|%s", bar, beat, spelling) end
  local got, expected = {}, {}
  for _, line in ipairs(run.printed) do
    local f = checks.fields(line)
    if f[1] == "note" and f[2] == "1" and f[3] == "Flute" then
      got[#got + 1] = key(tonumber(f[4]), tonumber(f[5]), f[6])
    end
  end
  for _, note in ipairs(want.flows[1].players[1].notes) do
    local pos = number(note.pos)
    if pos < 24 then
      expected[#expected + 1] = key(math.floor(pos / 4) + 1, pos % 4 + 1, note.spelling)
    else
      expected[#expected + 1] = key(7 + math.floor((pos - 24) / 3), (pos - 24) % 3 + 1, note.spelling)
    end
  end
  p:check("each flute note's bar and beat", checks.joined(got) == checks.joined(expected),
    "got " .. checks.joined(got) .. " | want " .. checks.joined(expected))
end
