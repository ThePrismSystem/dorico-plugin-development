-- Spike F2 to F4, the comparison: sets what spikes/f2_events.lua saw in Dorico beside the decoded file. Runs on
-- stock Lua 5.2, outside Dorico:
--   lua52 spikes/f2_compare.lua <f2_events result.json> <project.dorico>
-- For every stream Lua listed, it finds the file's eventStream with the same id, the blocks its block instances
-- place there, and their events; then matches every event in Lua's dump to a file event by id and checks the
-- position. It prints each stream's counts, the kinds that matched (dump kind = file definition), and anything that
-- didn't match.
local here = debug.getinfo(1, "S").source:match("^@(.*[/\\])") or "./"
local mine = here .. "../lib/?.lua;" .. here .. "lib/?.lua;" .. here .. "../fixtures/?.lua;" .. here .. "../lib/?.lua"
if not package.path:find(mine, 1, true) then package.path = mine .. ";" .. package.path end
local project = require("scorereader.project")
local tree = require("scorereader.tree")
local json = require("json")
local dump = require("scorereader.dorico.dump")

local f = assert(io.open(arg[1], "rb"))
local lua = json.decode(f:read("*a")).facts
f:close()
local t = project.readFile(arg[2]).tree

local function value(id, path)
  local n = tree.path(t, id, path)
  return n and tree.value(t, n)
end

local function number(s)
  local a, b = (s or ""):match("^(%-?%d+)/(%d+)$")
  if a then return tonumber(a) / tonumber(b) end
  return tonumber(s)
end

local flowNodes = tree.children(t, tree.path(t, 0, "flows/array"))
local kinds, problems = {}, 0
for fi, flow in ipairs(lua.flows) do
  local fnode = flowNodes[fi]
  -- the file's streams and which blocks each holds, through the block instances
  local streamType, blocksOf = {}, {}
  for _, s in ipairs(tree.children(t, tree.path(t, fnode, "eventStreams/array"))) do
    streamType[tonumber(value(s, "streamID"))] = value(s, "eventStreamType")
  end
  for _, bi in ipairs(tree.children(t, tree.path(t, fnode, "blockInstances/array"))) do
    local sid, bid = tonumber(value(bi, "streamID")), tonumber(value(bi, "blockID"))
    blocksOf[sid] = blocksOf[sid] or {}
    table.insert(blocksOf[sid], bid)
  end
  local eventsOfBlock = {}
  for _, b in ipairs(tree.children(t, tree.path(t, fnode, "blocks/array"))) do
    local list = {}
    for _, e in ipairs(tree.children(t, tree.child(t, b, "events"))) do
      list[tonumber(value(e, "eventID"))] = { kind = tree.name(t, e), pos = number(value(e, "position")) }
    end
    eventsOfBlock[tonumber(value(b, "blockID"))] = list
  end
  for _, s in ipairs(flow.streams) do
    local fileEvents, fileCount = {}, 0
    for _, bid in ipairs(blocksOf[s.id] or {}) do
      for id, e in pairs(eventsOfBlock[bid] or {}) do
        fileEvents[id] = e
        fileCount = fileCount + 1
      end
    end
    local parsed = dump.parse(s.dump)
    local unmatched = {}
    for _, ev in ipairs(parsed.events) do
      local fe = fileEvents[ev.id]
      if not fe then
        unmatched[#unmatched + 1] = "lua " .. ev.id .. " " .. tostring(ev.kind)
      else
        local key = tostring(ev.text and ev.text:match("^(k%w+)") or ev.kind) .. " = " .. fe.kind
        kinds[key] = (kinds[key] or 0) + 1
        if ev.pos and math.abs(ev.pos - fe.pos) > 1e-9 then
          unmatched[#unmatched + 1] = "pos " .. ev.id .. " lua " .. ev.pos .. " file " .. fe.pos
        end
        fileEvents[ev.id] = nil
      end
    end
    for id, e in pairs(fileEvents) do unmatched[#unmatched + 1] = "file " .. id .. " " .. e.kind end
    problems = problems + #unmatched
    print(string.format("flow %d stream %d %s: lua %d, file %d (%s)%s", flow.id, s.id, s.text:match("(k%w+)") or "?",
      #parsed.events, fileCount, tostring(streamType[s.id]), #unmatched > 0 and (" " .. table.concat(unmatched, "; "))
      or ""))
  end
end
local list = {}
for k, n in pairs(kinds) do list[#list + 1] = string.format("%5d  %s", n, k) end
table.sort(list)
print(table.concat(list, "\n"))
print("problems: " .. problems)
