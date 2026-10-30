-- An event's property entries, and which one applies in a given layout and block instance. Lua's propertyTable:get
-- can't read a value stored with a context, which is how values set by command or in Dorico's UI are stored; the
-- saved score has them all (docs/file-format.md, "Properties and contexts").
local tree = require("scorereader.tree")
local values = require("scorereader.values")

local props = {}

local STAVE_TYPES = { kNormal = true, kCondensed = true }

local function unreadable(name, text)
  error("scorereader: a context the reader can't read: " .. name .. " = " .. tostring(text), 0)
end

-- A context's children, in the forms seen in every Dorico 6 project read so far. Anything else stops the read, since
-- a context misread as "every layout" would put a part's value on the full score.
local function contextOf(t, context, x)
  local hasLayout, hasInstance = false, false
  for _, c in ipairs(tree.children(t, context)) do
    local name, text = tree.name(t, c), tree.value(t, c)
    if name == "layoutIDWithFrameChainID" then
      local ok, items = pcall(values.list, text)
      if not ok or #items ~= 3 or items[1].kind ~= "int" or items[2].kind ~= "int" or items[3].kind ~= "bool" then
        unreadable(name, text)
      end
      x.layout, x.frameChain, hasLayout = items[1].value, items[2].value, true
    elseif name == "blockInstanceID" then
      x.instance = tonumber(text:match("^%-?%d+$"))
      if not x.instance then unreadable(name, text) end
      hasInstance = true
    elseif name == "propertyOffset" then
      local ok, offset = pcall(values.string, text)
      if text ~= "" and not ok then unreadable(name, text) end
      x.offset = text == "" and "" or offset
    elseif name == "assignedStaveType" then
      if not STAVE_TYPES[text] then unreadable(name, text) end
      x.staveType = text
    else
      unreadable(name, text)
    end
  end
  if not hasLayout then unreadable("context", "no layoutIDWithFrameChainID") end
  if not hasInstance then unreadable("context", "no blockInstanceID") end
end

-- {{property, value (the raw typed text), layout, frameChain, instance, offset, staveType}} for every entry of the
-- event (or element) at node. layout, frameChain and instance are -1 for "every" and "any".
function props.entries(t, node)
  local out = {}
  local entries = tree.path(t, node, "propertyTable/entries")
  for _, e in ipairs(entries and tree.children(t, entries) or {}) do
    local typeNode, valueNode = tree.child(t, e, "propertyType"), tree.child(t, e, "value")
    if typeNode and valueNode then
      local x = { property = tree.value(t, typeNode), value = tree.value(t, valueNode), layout = -1, frameChain = -1,
        instance = -1 }
      local context = tree.child(t, e, "context")
      if context then contextOf(t, context, x) end
      out[#out + 1] = x
    end
  end
  return out
end

-- The raw value of property that applies in layoutId and block instance, or nil; then whether nothing applied but a
-- value exists for that layout and another instance. Only entries for that layout or every layout, and that instance
-- or any, count; the more specific wins, the layout first. Values for one frame chain or for condensed staves are
-- left out.
function props.pick(entries, property, layoutId, instance)
  local best, bestRank, elsewhere
  for _, x in ipairs(entries) do
    if x.property == property and x.frameChain == -1 and x.staveType ~= "kCondensed"
      and (x.layout == layoutId or x.layout == -1) then
      if x.instance == instance or x.instance == -1 then
        local rank = (x.layout == layoutId and 2 or 0) + (x.instance == instance and 1 or 0)
        if not bestRank or rank > bestRank then best, bestRank = x.value, rank end
      else
        elsewhere = true
      end
    end
  end
  return best, elsewhere == true and bestRank == nil
end

-- As pick, with the value decoded ('string: "C"' is "C", 'int: 4' is 4, 'null: ' is nil).
function props.get(entries, property, layoutId, instance)
  local raw, elsewhere = props.pick(entries, property, layoutId, instance)
  if raw == nil then return nil, elsewhere end
  return values.typed(raw).value, elsewhere
end

return props
