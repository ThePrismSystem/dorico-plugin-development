-- Spike F2 to F4, the Lua side: on a scratch copy, everything Lua can say about the score's streams and owners, to
-- set beside the decoded file (spikes/f2_compare.lua). For every flow: each stream in allStreams with tostring and
-- its dump, which voice streams flow.instruments says each instrument owns, the stave and player streams; then the
-- players with their instruments, and the layouts with their players. Read-only:
--   python tools/run_lua.py spikes/f2_events.lua --open <project.dorico> > result.json
local here = debug.getinfo(1, "S").source:match("^@(.*[/\\])")
local mine = here .. "?.lua;" .. here .. "lib/?.lua"
for name in pairs(package.loaded) do
  if package.searchpath(name, mine) then package.loaded[name] = nil end
end
if not package.path:find(mine, 1, true) then package.path = mine .. ";" .. package.path end
local probe = require("probe")

local function ids(list)
  local out = {}
  for i = 1, #list do out[i] = list[i].id end
  return out
end

probe.run("f2_events", function(p)
  local app = DoApp.DoApp()
  local score = app.currentScore
  local flows = {}
  for _, flow in ipairs(score.flows) do
    local streams = {}
    for _, s in ipairs(flow.allStreams) do
      streams[#streams + 1] = { id = s.id, text = tostring(s), dump = s:dump() }
    end
    local owners = {}
    for i, inst in ipairs(flow.instruments) do owners[i] = inst.id end
    flows[#flows + 1] = { id = flow.id, streams = streams, voiceStreams = ids(flow.voiceStreams),
      voiceOwners = owners, staveStreams = ids(flow.staveStreams), playerStreams = ids(flow.playerStreams),
      timebaseStreams = ids(flow.timebaseStreams), players = #flow.players }
  end
  local players = {}
  for _, pl in ipairs(score.players) do
    players[#players + 1] = { name = tostring(pl), instruments = ids(pl.instruments) }
  end
  local layouts = {}
  for _, l in ipairs(score.layouts) do
    local owners = {}
    for _, pl in ipairs(l.players) do owners[#owners + 1] = pl.instruments[1].id end
    layouts[#layouts + 1] = { id = l.id, text = tostring(l), playerInstruments = owners }
  end
  p:fact("flows", flows)
  p:fact("players", players)
  p:fact("layouts", layouts)
end)
