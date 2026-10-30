-- fixtures/dumpparse.lua, with stand-ins for Dorico's score, players and flow.
local here = (arg and arg[0] or ""):match("^(.*[/\\])") or "./"
package.path = here .. "../fixtures/?.lua;" .. package.path
local dumpparse = require("dumpparse")

-- A player whose tostring is its name, holding instruments with these ids.
local function player(name, instrumentIds)
  local instruments = {}
  for i, id in ipairs(instrumentIds) do instruments[i] = { id = id } end
  return setmetatable({ instruments = instruments }, { __tostring = function() return name end })
end

return {
  owners_by_instrument = function(t)
    local score = { players = { player("Flute", { 1 }), player("Piano", { 2, 3 }) } }
    local flow = { voiceStreams = { { id = 10 }, { id = 11 }, { id = 12 } },
      instruments = { { id = 1 }, { id = 2 }, { id = 3 } } }
    local owners = dumpparse.owners(score, flow)
    t:eq(owners[10], "Flute")
    t:eq(owners[11], "Piano")
    t:eq(owners[12], "Piano", "a piano's second instrument")
  end,
}
