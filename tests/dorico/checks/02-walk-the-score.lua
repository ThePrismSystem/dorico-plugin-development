-- 02-walk-the-score.lua listed the sample's players by their exact names (a B-flat trumpet's token, a comma and an
-- ampersand), each flow with its players, and an owner for every voice.
local checks = require("checks")

return function(p, run)
  local want = checks.expected()
  local players, flows = {}, {}
  for _, line in ipairs(run.printed) do
    local name = line:match("^player: (.*)$")
    local n, np, nv = line:match("^flow (%d+): (%d+) players, (%d+) voices, %d+ staves$")
    local owner = line:match("^  voice: (.*)$")
    if name then players[#players + 1] = name end
    if n then flows[#flows + 1] = { players = tonumber(np), voices = tonumber(nv), owners = {} } end
    if owner and #flows > 0 then table.insert(flows[#flows].owners, owner) end
  end

  local names = {}
  for i, pl in ipairs(want.flows[1].players) do names[i] = pl.name end
  p:check("every player, by name, in order", table.concat(players, " | ") == table.concat(names, " | "),
    table.concat(players, " | "))
  p:check("the trumpet's name has Dorico's flat token", checks.printed(run, "player: Trumpet Zoë (B{@flat@})"))
  p:check("the violin's name keeps its comma and ampersand", checks.printed(run, "player: Violin, solo & tutti"))
  p:check("one line per flow", #flows == #want.flows, #flows)

  for n, flow in ipairs(want.flows) do
    local got = flows[n] or { owners = {} }
    p:check("flow " .. n .. " players", got.players == #flow.players, got.players)
    p:check("flow " .. n .. " has a voice line per voice", #got.owners == got.voices, #got.owners)
    local owns = {}
    for _, o in ipairs(got.owners) do owns[o] = true end
    p:check("flow " .. n .. " has no voice without an owner", not owns["?"])
    for _, player in ipairs(flow.players) do
      if #player.notes > 0 then
        p:check("flow " .. n .. " names " .. player.name .. " as an owner", owns[player.name])
      end
    end
  end
end
