-- Project info, the library's names, players with their instruments, and layouts.
local tree = require("scorereader.tree")

local players = {}

-- {[entityID] = {name, node}} for every library definition that has both: paragraph styles, playing techniques and
-- their appearances, notehead sets, instruments and the rest.
function players.library(ctx)
  local t, out = ctx.t, {}
  local stack = { ctx.node(0, "library") }
  while #stack > 0 do
    local id = table.remove(stack)
    local entity, name = tree.child(t, id, "entityID"), tree.child(t, id, "name")
    if entity and name then out[tree.value(t, entity)] = { name = tree.value(t, name), node = id } end
    for _, k in ipairs(tree.children(t, id)) do stack[#stack + 1] = k end
  end
  return out
end

-- Every child of info by name: title, subtitle, composer, lyricist, copyright, createdVersion, lastSavedVersion and
-- the rest.
function players.info(ctx)
  local out = {}
  for _, c in ipairs(tree.children(ctx.t, ctx.node(0, "info"))) do out[tree.name(ctx.t, c)] = tree.value(ctx.t, c) end
  return out
end

-- The library's instrument definitions by entityID.
local function definitions(ctx)
  local out = {}
  for _, d in ipairs(ctx.list(0, "library/instruments/entities")) do
    local id = ctx.opt(d, "entityID")
    if id then out[id] = d end
  end
  return out
end

local function instrumentOf(ctx, node, defs)
  local inst = { id = ctx.int(node, "instrumentID"), entityID = ctx.text(node, "entityID"),
    staves = tonumber(ctx.opt(node, "numStaves") or "1"),
    name = ctx.opt(node, "nameData/singularFullName") or "",
    range = { standard = ctx.opt(node, "standardRange"), advanced = ctx.opt(node, "advancedRange") } }
  -- Without its definition an instrument would read as concert pitch, whatever it is.
  local def = defs[inst.entityID]
    or ctx.fail("instrument " .. inst.id .. ": " .. inst.entityID .. " has no definition in the library")
  local pitched = tree.child(ctx.t, def, "pitchedInstrumentData")
  if pitched then
    -- written = sounding + this interval: a B-flat clarinet is written a major second (1 step, 2 semitones) up
    inst.transposition = { diatonic = ctx.int(pitched, "transposedDiatonicTransposition"),
      chromatic = ctx.int(pitched, "transposedChromaticTransposition"),
      octaves = ctx.int(pitched, "concertOctaveTransposition") }
  end
  return inst
end

-- The players in score order, and every instrument by its id.
function players.players(ctx)
  local t, defs = ctx.t, definitions(ctx)
  local list, byId = {}, {}
  for _, p in ipairs(tree.children(t, ctx.node(0, "scorePlayers/array"))) do
    local player = { id = ctx.int(p, "playerID"), name = ctx.text(p, "displayName"),
      shortName = ctx.opt(p, "displayShortName") or "", baseName = ctx.opt(p, "baseName") or "", instruments = {} }
    for _, i in ipairs(ctx.list(p, "instruments")) do
      local inst = instrumentOf(ctx, i, defs)
      inst.playerId = player.id
      player.instruments[#player.instruments + 1] = inst
      byId[inst.id] = inst
    end
    list[#list + 1] = player
  end
  return list, byId
end

local function ids(text)
  local out = {}
  for n in (text or ""):gmatch("%-?%d+") do out[#out + 1] = tonumber(n) end
  return out
end

-- The layouts in the file's order: the full score first, then parts.
function players.layouts(ctx)
  local t, out = ctx.t, {}
  for _, l in ipairs(tree.children(t, ctx.node(0, "layouts/array"))) do
    local layout = { id = ctx.int(l, "layoutID"), name = ctx.opt(l, "layoutName") or "",
      number = tonumber(ctx.opt(l, "layoutNumber") or ""), type = ctx.text(l, "layoutType"),
      flowIds = ids(ctx.opt(l, "flowIDs")), playerIds = {} }
    for _, entry in ipairs(ctx.list(l, "layoutPlayers/array")) do
      layout.playerIds[#layout.playerIds + 1] = ctx.int(entry, "playerID")
    end
    out[#out + 1] = layout
  end
  return out
end

return players
