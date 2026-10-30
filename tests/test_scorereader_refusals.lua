-- Changes to the reading fixture that the reader must refuse. Each case renames a node (as a new Dorico might move
-- it) or gives it a value the reader hasn't seen, reads the tree, and puts the node back.
local project = require("scorereader.project")
local score = require("scorereader.score")
local tree = require("scorereader.tree")

local here = debug.getinfo(1, "S").source:match("^@(.*[/\\])") or "./"

local READING
local function reading()
  READING = READING or project.readFile(here .. "../fixtures/6.2.30/reading.dorico").tree
  return READING
end

-- The error score.read raises with node id renamed to newName and/or given newValue, or nil.
local function errorWith(id, newName, newValue)
  local t = reading()
  local oldName, oldValue = t.nameOf[id], t.valueOf[id]
  if newName then
    if not t.nameIndex[newName] then
      t.names[#t.names + 1] = newName
      t.nameIndex[newName] = #t.names - 1
    end
    t.nameOf[id] = t.nameIndex[newName]
  end
  if newValue then
    t.values[#t.values + 1] = newValue
    t.valueOf[id] = #t.values - 1
  end
  local ok, err = pcall(score.read, t)
  t.nameOf[id], t.valueOf[id] = oldName, oldValue
  return not ok and tostring(err) or nil
end

local function refused(t, err, want, label)
  t:ok(err and err:find("^scorereader: ") and err:find(want, 1, true) and err:find("(fileVersion 1.1452", 1, true),
    label .. ": " .. tostring(err))
end

local function firstFlow(t)
  return tree.children(t, tree.path(t, 0, "flows/array"))[1]
end

local function first(t, id, path)
  return tree.children(t, tree.path(t, id, path))[1]
end

-- The first event of a definition in the first flow's blocks.
local function firstEvent(t, definition)
  for _, b in ipairs(tree.children(t, tree.path(t, firstFlow(t), "blocks/array"))) do
    for _, e in ipairs(tree.children(t, tree.child(t, b, "events"))) do
      if tree.name(t, e) == definition then return e end
    end
  end
  error("no " .. definition)
end

-- The element of the first flow's tableName that the event points to by idField.
local function elementOf(t, event, idField, tableName)
  local id = tree.value(t, tree.child(t, event, idField))
  for _, el in ipairs(tree.children(t, tree.path(t, firstFlow(t), "elementTables/array/" .. tableName .. "/array"))) do
    if tree.value(t, tree.child(t, el, "elementID")) == id then return el end
  end
  error("no element " .. id .. " in " .. tableName)
end

return {
  a_flow_missing_a_node_the_reader_walks = function(t)
    local tr = reading()
    local flow = firstFlow(tr)
    local fpi = tree.child(tr, first(tr, flow, "flowPlayers/array"), "flowPlayerInstruments")
    local cases = {
      { tree.child(tr, flow, "flowInfo"), "a flow has no flowInfo" },
      { tree.child(tr, first(tr, flow, "elementTables/array"), "array"), "no array in" },
      { tree.child(tr, first(tr, flow, "blocks/array"), "events"), "no events in" },
      { fpi, "no flowPlayerInstruments in" },
      { tree.child(tr, tree.children(tr, fpi)[1], "staveStreamInfos"), "no staveStreamInfos in" },
      { tree.child(tr, tree.children(tr, fpi)[1], "voiceStreamInfos"), "no voiceStreamInfos in" },
    }
    for _, c in ipairs(cases) do refused(t, errorWith(c[1], "kRenamed"), c[2], c[2]) end
  end,
  players_layouts_and_the_library_missing_a_node = function(t)
    local tr = reading()
    local cases = {
      { tree.child(tr, first(tr, 0, "scorePlayers/array"), "instruments"), "no instruments in" },
      { tree.child(tr, first(tr, 0, "layouts/array"), "layoutPlayers"), "no layoutPlayers/array in" },
      { tree.path(tr, 0, "library/instruments/entities"), "the root has no library/instruments/entities" },
    }
    for _, c in ipairs(cases) do refused(t, errorWith(c[1], "kRenamed"), c[2], c[2]) end
  end,
  events_missing_a_node_the_reader_walks = function(t)
    local tr = reading()
    local textContent = tree.child(tr, firstEvent(tr, "TextEventDefinition"), "content")
    local group = elementOf(tr, firstEvent(tr, "DynamicGroupEventDefinition"), "dynamicGroupID",
      "DynamicGroupElementTableDefinition")
    local bars = elementOf(tr, firstEvent(tr, "BarDivisionEventDefinition"), "barDivisionElementID",
      "BarDivisionElementTableDefinition")
    local cases = {
      { tree.child(tr, textContent, "paragraphs"), "no paragraphs in" },
      { tree.child(tr, first(tr, textContent, "paragraphs"), "fragments"), "no fragments in" },
      { tree.child(tr, group, "subElements"), "no subElements in" },
      { tree.path(tr, bars, "barDivisionData/timeSignature/timeSignaturesAndDivisions"),
        "no barDivisionData/timeSignature/timeSignaturesAndDivisions in" },
    }
    for _, c in ipairs(cases) do refused(t, errorWith(c[1], "kRenamed"), c[2], c[2]) end
  end,
  a_major_key_with_no_root = function(t)
    local tr = reading()
    local el = elementOf(tr, firstEvent(tr, "TonalityDivisionEventDefinition"), "tonalityDivisionElementID",
      "TonalityDivisionElementTableDefinition")
    refused(t, errorWith(tree.path(tr, el, "tonalityDivisionData/keySignature/root/root/noteName"), "kRenamed"),
      "is major but has no root", "a major key")
  end,
  a_definition_missing_from_the_library = function(t)
    local tr = reading()
    local instrument = first(tr, first(tr, 0, "scorePlayers/array"), "instruments")
    refused(t, errorWith(tree.child(tr, instrument, "entityID"), nil, "instrument.none"),
      "instrument.none has no definition in the library", "an instrument")
    refused(t, errorWith(tree.child(tr, firstEvent(tr, "PlayingTechniqueEventDefinition"), "appearanceEntityID"), nil,
      "pta.none"), "pta.none has no definition in the library", "a playing technique")
  end,
}
