-- instrument-report.lua listed each flow with its title and players, each player's instrument and note count, and
-- the most players playing at once, all as expected.json has them.
local checks = require("checks")

local INSTRUMENTS = { "Flute", "Trumpet Zoë", "Violin, solo & tutti", "Piano" }

return function(p, run)
  local want = {}
  for n, flow in ipairs(checks.expected().flows) do
    want[#want + 1] = string.format('flow %d "%s": %d players', n, flow.title, #flow.players)
    local spans = {}
    for i, player in ipairs(flow.players) do
      want[#want + 1] = string.format("  %s | %s | %d notes", player.name, INSTRUMENTS[i], #player.notes)
      for _, note in ipairs(player.notes) do
        if not note.grace then spans[#spans + 1] = { i, note.pos, note.pos + note.duration } end
      end
    end
    local most = 0
    for _, s in ipairs(spans) do
      local playing = {}
      for _, o in ipairs(spans) do
        if o[2] <= s[2] and s[2] < o[3] then playing[o[1]] = true end
      end
      local c = 0
      for _ in pairs(playing) do c = c + 1 end
      if c > most then most = c end
    end
    want[#want + 1] = "  most players playing at once: " .. most
  end
  p:check("the report", table.concat(run.printed, " / ") == table.concat(want, " / "),
    "got " .. table.concat(run.printed, " / ") .. " | want " .. table.concat(want, " / "))
  p:check("no marker left", #checks.texts(1) == 0 and #checks.texts(2) == 0)
end
