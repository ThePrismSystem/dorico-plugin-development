-- The whole score as plain tables: project info, players and instruments, layouts, and every flow's streams and
-- events, each event with its position, duration and what its kind holds (docs/file-format.md describes where each
-- comes from). Ids are the ones Lua gives, so an event here can be matched to one in stream:dump().
--
--   local s = score.readFile(path)              -- or score.read(bytes), or score.read(tree)
--   for _, e in ipairs(score.eventsOf(s, s.flows[1], s.players[1])) do ... end
local project = require("scorereader.project")
local format = require("scorereader.format")
local tree = require("scorereader.tree")
local values = require("scorereader.values")
local props = require("scorereader.props")
local players = require("scorereader.read.players")
local notes = require("scorereader.read.notes")
local text = require("scorereader.read.text")
local dynamics = require("scorereader.read.dynamics")
local signatures = require("scorereader.read.signatures")
local marks = require("scorereader.read.marks")

local score = {}

-- definition name: {kind, reader}; any other definition is read as kind "other" with only the common fields.
local KINDS = {
  NoteEventDefinition = { "note", notes.note },
  GraceNoteEventDefinition = { "grace", notes.note },
  RestEventDefinition = { "rest" },
  BarRestEventDefinition = { "barRest" },
  TupletEventDefinition = { "tuplet", notes.tuplet },
  SlurEventDefinition = { "slur" },
  TextEventDefinition = { "text", text.text },
  LyricEventDefinition = { "lyric", text.lyric },
  ChordSymbolEventDefinition = { "chordSymbol", text.chordSymbol },
  DynamicGroupEventDefinition = { "dynamic", dynamics.group },
  BarDivisionEventDefinition = { "timeSignature", signatures.time },
  TonalityDivisionEventDefinition = { "keySignature", signatures.key },
  ImmediateTempoChangeEventDefinition = { "tempo", marks.tempo },
  RehearsalMarkEventDefinition = { "rehearsalMark" },
  PlayingTechniqueEventDefinition = { "playingTechnique", marks.technique },
  ClefEventDefinition = { "clef", marks.clef },
}

local STREAMS = { kGlobalTimebaseStream = "timebase", kInstrumentStaveStream = "stave", kVoiceStream = "voice",
  kPlayerStream = "player", kAutomationStream = "automation" }

-- What every reader gets: the tree, the score so far, and accessors that stop the read with a message naming the
-- node and the format when a node it relies on isn't there.
local function newContext(s)
  local t = s.tree
  local ctx = { t = t, score = s }
  function ctx.fail(msg)
    error("scorereader: " .. msg .. " (fileVersion " .. s.format.fileVersion .. ", saved by Dorico "
      .. s.format.lastSavedVersion .. ")", 0)
  end
  function ctx.node(id, path)
    return tree.path(t, id, path) or ctx.fail("no " .. path .. " in " .. tree.name(t, id) .. " #" .. id)
  end
  function ctx.text(id, path)
    return tree.value(t, ctx.node(id, path))
  end
  function ctx.opt(id, path)
    local n = tree.path(t, id, path)
    return n and tree.value(t, n)
  end
  -- A list the reader walks must be there, even when empty: a missing one would read as a score with nothing in it.
  function ctx.list(id, path)
    return tree.children(t, ctx.node(id, path))
  end
  function ctx.optList(id, path)
    local n = tree.path(t, id, path)
    return n and tree.children(t, n) or {}
  end
  function ctx.int(id, path)
    local v = ctx.text(id, path)
    return tonumber(v:match("^%-?%d+$")) or ctx.fail("not a whole number: " .. path .. " = " .. v)
  end
  function ctx.read(fn, raw, what)
    local ok, v = pcall(fn, raw)
    if not ok then ctx.fail(what .. ": " .. tostring(v)) end
    return v
  end
  function ctx.position(id, path, what)
    return ctx.read(values.position, ctx.text(id, path), what)
  end
  -- An event's property entries (scorereader.props), read once and kept in s.cache.
  function ctx.entries(e)
    local cached = s.cache[e]
    if not cached then
      cached = ctx.read(function(node) return props.entries(t, node) end, e.node, "event " .. e.id)
      s.cache[e] = cached
    end
    return cached
  end
  return ctx
end

-- Each element table's elements by elementID, keyed by table name.
local function elementsOf(ctx, flowNode)
  local out = {}
  for _, tableNode in ipairs(ctx.list(flowNode, "elementTables/array")) do
    local byId = {}
    for _, el in ipairs(ctx.list(tableNode, "array")) do byId[ctx.int(el, "elementID")] = el end
    out[tree.name(ctx.t, tableNode)] = byId
  end
  return out
end

local function readFlow(ctx, flowNode)
  local t = ctx.t
  local flow = { id = ctx.int(flowNode, "flowID"), title = ctx.text(flowNode, "flowName"), streams = {},
    streamById = {}, events = {}, info = {} }
  for _, c in ipairs(ctx.list(flowNode, "flowInfo")) do flow.info[tree.name(t, c)] = tree.value(t, c) end
  flow.elements = elementsOf(ctx, flowNode)

  for _, sNode in ipairs(ctx.list(flowNode, "eventStreams/array")) do
    local raw = ctx.text(sNode, "eventStreamType")
    local stream = { id = ctx.int(sNode, "streamID"), type = STREAMS[raw] or "other", rawType = raw, instances = {},
      events = {} }
    flow.streams[#flow.streams + 1] = stream
    flow.streamById[stream.id] = stream
  end
  -- who owns each stream (docs/file-format.md, "Streams and what they hold")
  for _, fp in ipairs(ctx.list(flowNode, "flowPlayers/array")) do
    local playerId = ctx.int(fp, "playerID")
    local ps = flow.streamById[ctx.int(fp, "eventStreamID")]
    if ps then ps.playerId = playerId end
    for _, inst in ipairs(ctx.list(fp, "flowPlayerInstruments")) do
      local instrumentId = ctx.int(inst, "instrumentID")
      for _, info in ipairs(ctx.list(inst, "staveStreamInfos")) do
        local s = flow.streamById[ctx.int(info, "staveStreamID")]
        if s then s.playerId, s.instrumentId, s.staff = playerId, instrumentId, ctx.int(info, "nthStaveInInstrument") end
      end
      for _, info in ipairs(ctx.list(inst, "voiceStreamInfos")) do
        local s = flow.streamById[ctx.int(info, "voiceStreamID")]
        if s then s.playerId, s.instrumentId = playerId, ctx.int(info, "instrumentID") end
      end
    end
  end

  local blocks = {}
  for _, b in ipairs(ctx.list(flowNode, "blocks/array")) do
    blocks[ctx.int(b, "blockID")] = b
  end
  for _, bi in ipairs(ctx.list(flowNode, "blockInstances/array")) do
    local stream = flow.streamById[ctx.int(bi, "streamID")]
    local inst = { id = ctx.int(bi, "blockInstanceID"), blockId = ctx.int(bi, "blockID"),
      position = ctx.position(bi, "position", "a block instance's position") }
    if not stream then ctx.fail("block instance " .. inst.id .. " is in no stream the flow lists") end
    stream.instances[#stream.instances + 1] = inst
  end

  local fctx = setmetatable({ flow = flow }, { __index = ctx })
  -- The element of the flow's table tableName that an event's idField names; what names the event in the error.
  function fctx.element(e, node, idField, tableName, what)
    local id = ctx.int(node, idField)
    return (flow.elements[tableName] or {})[id] or ctx.fail(what .. " " .. e.id .. " points to no element " .. id)
  end
  for _, stream in ipairs(flow.streams) do
    table.sort(stream.instances, function(a, b) return values.toNumber(a.position) < values.toNumber(b.position) end)
    for _, inst in ipairs(stream.instances) do
      local block = blocks[inst.blockId] or ctx.fail("block " .. inst.blockId .. " isn't in the flow")
      for _, node in ipairs(ctx.list(block, "events")) do
        local definition = tree.name(t, node)
        local kind = KINDS[definition] or { "other" }
        local e = { id = ctx.int(node, "eventID"), definition = definition, kind = kind[1], flowId = flow.id,
          streamId = stream.id, blockId = inst.blockId, instanceId = inst.id, node = node,
          position = values.add(inst.position, ctx.position(node, "position", "a position")),
          duration = ctx.position(node, "duration", "a duration") }
        if kind[2] then kind[2](fctx, e, node) end
        stream.events[#stream.events + 1] = e
        flow.events[#flow.events + 1] = e
        ctx.score.events[e.id] = ctx.score.events[e.id] or e
      end
    end
  end
  return flow
end

-- A decoded tree, the table project.read returns, or the bytes of a .dorico.
function score.read(input)
  local t = type(input) == "string" and project.read(input).tree or input.tree or input
  local s = { tree = t, format = format.detect(t), events = {}, flows = {}, flowById = {}, cache = {} }
  local ctx = newContext(s)
  s.library = players.library(ctx)
  s.info = players.info(ctx)
  s.players, s.instruments = players.players(ctx)
  s.layouts = players.layouts(ctx)
  for _, f in ipairs(ctx.list(0, "flows/array")) do
    local flow = readFlow(ctx, f)
    s.flows[#s.flows + 1] = flow
    s.flowById[flow.id] = flow
  end
  return s
end

function score.readFile(path)
  return score.read(project.readFile(path))
end

-- The player that owns an event's stream, or nil for the timebase stream.
function score.ownerOf(s, e)
  local stream = s.flowById[e.flowId].streamById[e.streamId]
  for _, p in ipairs(s.players) do
    if p.id == stream.playerId then return p end
  end
end

-- Every event in a player's streams in a flow (voices, staves and the player's own stream), in time order.
function score.eventsOf(s, flow, player)
  local out = {}
  for _, stream in ipairs(flow.streams) do
    if stream.playerId == player.id then
      for _, e in ipairs(stream.events) do out[#out + 1] = e end
    end
  end
  table.sort(out, function(a, b)
    local x, y = values.toNumber(a.position), values.toNumber(b.position)
    if x ~= y then return x < y end
    return a.id < b.id
  end)
  return out
end

-- A player's part: the part layout holding that player alone.
function score.partOf(s, player)
  for _, l in ipairs(s.layouts) do
    if l.type == "kPartLayout" and #l.playerIds == 1 and l.playerIds[1] == player.id then return l end
  end
end

-- An event's property entries (scorereader.props), read once.
function score.entries(s, e)
  return s.cache[e] or newContext(s).entries(e)
end

-- The decoded value of a property that applies to an event in a layout (the event's own block instance), or nil.
function score.value(s, e, property, layoutId)
  return (props.get(score.entries(s, e), property, layoutId, e.instanceId))
end

-- Whether a text is above the staff in a layout. Edit.FlipItem stores the flip as kTextEventAboveOrBelow for the
-- layout on screen, and the text keeps its own aboveOrBelow for the rest.
function score.above(s, e, layoutId)
  local flipped = score.value(s, e, "kTextEventAboveOrBelow", layoutId)
  if flipped then return flipped == "kAbove" end
  return e.above
end

return score
