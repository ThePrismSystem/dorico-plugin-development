-- Dynamics. A dynamic group event points to an element whose sub-elements are the dynamics in the group, each at a
-- position from the group's start (docs/file-format.md, "Dynamics").
local tree = require("scorereader.tree")
local values = require("scorereader.values")

local dynamics = {}

-- "mf", "ff" from an immediate dynamic's intensity: {int: family (0 forte, 1 piano)}, {}, {bool: mezzo}, {int: how
-- many letters}.
local function immediateName(ctx, raw)
  local items = ctx.read(values.list, raw, "a dynamic's intensity")
  local family, mezzo, count = items[1], items[3], items[4]
  if not (family and family.kind == "int" and (family.value == 0 or family.value == 1) and mezzo
    and mezzo.kind == "bool" and count) then
    ctx.fail("a dynamic's intensity the reader can't read: " .. raw)
  end
  local letter = family.value == 0 and "f" or "p"
  if mezzo.value then return "m" .. letter end
  if count.kind ~= "int" or count.value < 1 then ctx.fail("a dynamic's intensity the reader can't read: " .. raw) end
  return string.rep(letter, count.value)
end

local function gradualName(ctx, sub)
  local kind = ctx.text(sub, "type")
  if kind == "kMessaDiVoce" then return "messa di voce" end
  local direction = ctx.text(sub, "direction")
  if kind == "kCrescOrDim" and direction == "kGradualDynamicUp" then return "crescendo" end
  if kind == "kCrescOrDim" and direction == "kGradualDynamicDown" then return "diminuendo" end
  ctx.fail("a gradual dynamic the reader can't read: " .. kind .. " " .. direction)
end

-- "fp": start letters then end letters, forte first when the dynamic goes down.
local function combinedName(ctx, sub)
  local start, finish = ctx.int(sub, "startIntensity"), ctx.int(sub, "endIntensity")
  local direction = ctx.text(sub, "direction")
  if direction == "kDown" then return string.rep("f", start) .. string.rep("p", finish) end
  if direction == "kUp" then return string.rep("p", start) .. string.rep("f", finish) end
  ctx.fail("a combined dynamic the reader can't read: " .. direction)
end

-- dynamics = {{kind (immediate, gradual, force, combined), name, position, duration (gradual only)}}.
function dynamics.group(ctx, e, node)
  local id = ctx.int(node, "dynamicGroupID")
  local el = (ctx.flow.elements.DynamicGroupElementTableDefinition or {})[id]
    or ctx.fail("dynamic " .. e.id .. " points to no element " .. id)
  e.dynamics = {}
  for _, sub in ipairs(ctx.list(el, "subElements")) do
    local definition = tree.name(ctx.t, sub)
    local d = { position = values.add(e.position, ctx.read(values.position, ctx.text(sub, "position"),
      "a dynamic's position")) }
    if definition == "ImmediateChangeDynamicDefinition" then
      d.kind, d.name = "immediate", immediateName(ctx, ctx.text(sub, "intensity"))
    elseif definition == "GradualChangeDynamicDefinition" then
      d.kind, d.name = "gradual", gradualName(ctx, sub)
      d.duration = ctx.read(values.position, ctx.text(sub, "duration"), "a hairpin's duration")
    elseif definition == "ForceDynamicDefinition" then
      local kind = ctx.text(sub, "type")
      d.kind, d.name = "force", (kind:match("^kForceDynamic(%a+)$")
        or ctx.fail("a force dynamic the reader can't read: " .. kind)):lower()
    elseif definition == "CombinedDynamicDefinition" then
      d.kind, d.name = "combined", combinedName(ctx, sub)
    else
      ctx.fail("dynamic " .. e.id .. " holds a " .. definition .. ", which the reader doesn't know")
    end
    e.dynamics[#e.dynamics + 1] = d
  end
end

return dynamics
