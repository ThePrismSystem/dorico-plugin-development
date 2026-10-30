-- Who owns each voice stream, for the fixture scripts, the spikes and the in-Dorico cases. They parse stream:dump()
-- with scorereader.dorico.dump; this module once held a copy of that parser, hence its name.
local dumpparse = {}

-- {[voice stream id] = player name}: flow.instruments[i] owns flow.voiceStreams[i], and a player's name is
-- tostring(player).
function dumpparse.owners(score, flow)
  local nameOf = {}
  for _, pl in ipairs(score.players) do
    for _, ins in ipairs(pl.instruments) do nameOf[ins.id] = tostring(pl) end
  end
  local owners = {}
  for i, s in ipairs(flow.voiceStreams) do owners[s.id] = nameOf[flow.instruments[i].id] end
  return owners
end

return dumpparse
