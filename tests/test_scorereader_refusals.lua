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

-- The first dynamic of a definition (ImmediateChangeDynamicDefinition and so on) in the first flow's dynamic groups.
local function firstDynamic(t, definition)
  for _, tb in ipairs(tree.children(t, tree.path(t, firstFlow(t), "elementTables/array"))) do
    if tree.name(t, tb) == "DynamicGroupElementTableDefinition" then
      for _, el in ipairs(tree.children(t, tree.child(t, tb, "array"))) do
        for _, sub in ipairs(tree.children(t, tree.child(t, el, "subElements"))) do
          if tree.name(t, sub) == definition then return sub end
        end
      end
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
  blocks_and_instances_that_dont_fit = function(t)
    local tr = reading()
    local instance = first(tr, firstFlow(tr), "blockInstances/array")
    refused(t, errorWith(tree.child(tr, instance, "streamID"), nil, "99999"), "is in no stream the flow lists",
      "an instance's stream")
    refused(t, errorWith(tree.child(tr, instance, "blockID"), nil, "99999"), "block 99999 isn't in the flow",
      "an instance's block")
    refused(t, errorWith(tree.child(tr, instance, "position"), nil, "x"), "a block instance's position: ",
      "an instance's position")
  end,
  numbers_and_positions_that_dont_parse = function(t)
    local tr = reading()
    local note = firstEvent(tr, "NoteEventDefinition")
    local cases = {
      { tree.child(tr, note, "eventID"), "not a whole number: eventID = x" },
      { tree.child(tr, note, "position"), "a position: " },
      { tree.child(tr, note, "duration"), "a duration: " },
      { tree.child(tr, firstEvent(tr, "GraceNoteEventDefinition"), "notatedDuration"), "a notated duration: " },
      { tree.child(tr, firstDynamic(tr, "ImmediateChangeDynamicDefinition"), "position"), "a dynamic's position: " },
      { tree.child(tr, firstDynamic(tr, "GradualChangeDynamicDefinition"), "duration"), "a hairpin's duration: " },
    }
    for _, c in ipairs(cases) do refused(t, errorWith(c[1], nil, "x"), c[2], c[2]) end
  end,
  an_event_pointing_to_no_element = function(t)
    local tr = reading()
    local cases = {
      { "DynamicGroupEventDefinition", "dynamicGroupID", "dynamic" },
      { "BarDivisionEventDefinition", "barDivisionElementID", "bar division" },
      { "TonalityDivisionEventDefinition", "tonalityDivisionElementID", "tonality division" },
      { "LyricEventDefinition", "lyricElementID", "lyric" },
    }
    for _, c in ipairs(cases) do
      local err = errorWith(tree.child(tr, firstEvent(tr, c[1]), c[2]), nil, "99999")
      t:ok(err and err:find("^scorereader: " .. c[3] .. " %d+ points to no element 99999 %(fileVersion"),
        c[3] .. ": " .. tostring(err))
    end
  end,
  notes_the_reader_cant_spell = function(t)
    local tr = reading()
    local note = firstEvent(tr, "NoteEventDefinition")
    local entry = first(tr, note, "propertyTable/entries")
    refused(t, errorWith(tree.child(tr, entry, "propertyType"), nil, "kOther"), "has no spelling the reader knows",
      "no kNoteSpelling")
    refused(t, errorWith(tree.child(tr, entry, "value"), nil, 'string: "H"'), "has no spelling the reader knows",
      "a letter that isn't one")
    refused(t, errorWith(tree.path(tr, entry, "context/layoutIDWithFrameChainID"), nil,
      "steamVariantList:list: {int: 0}, {int: -1}, {bool: false}"), "has no spelling the reader knows",
      "a spelling for one layout only")
    refused(t, errorWith(tree.child(tr, note, "pitch"), nil, "200"), "but sounds MIDI 200", "a pitch out of reach")
  end,
  values_the_readers_dont_know = function(t)
    local tr = reading()
    local key = elementOf(tr, firstEvent(tr, "TonalityDivisionEventDefinition"), "tonalityDivisionElementID",
      "TonalityDivisionElementTableDefinition")
    local lyric = elementOf(tr, firstEvent(tr, "LyricEventDefinition"), "lyricElementID", "LyricElementTableDefinition")
    local immediate = tree.child(tr, firstDynamic(tr, "ImmediateChangeDynamicDefinition"), "intensity")
    local cases = {
      { tree.path(tr, key, "tonalityDivisionData/keySignature/root/tonalityType"), "kWeird",
        "has a type the reader doesn't know: kWeird" },
      { tree.child(tr, lyric, "syllableType"), "kWeird", "has a syllable type the reader doesn't know: kWeird" },
      { tree.child(tr, lyric, "lineType"), "kWeird", "has a line type the reader doesn't know: kWeird" },
      { immediate, "x", "a dynamic's intensity: " },
      { immediate, "steamVariantList:list: {int: 5}, {}, {bool: false}, {int: 1}",
        "a dynamic's intensity the reader can't read" },
      { immediate, "steamVariantList:list: {int: 0}, {}, {bool: false}, {int: 0}",
        "a dynamic's intensity the reader can't read" },
      { tree.child(tr, firstDynamic(tr, "GradualChangeDynamicDefinition"), "type"), "kWeird",
        "a gradual dynamic the reader can't read: kWeird" },
      { tree.child(tr, firstDynamic(tr, "ForceDynamicDefinition"), "type"), "kWeird",
        "a force dynamic the reader can't read: kWeird" },
      { tree.child(tr, firstDynamic(tr, "CombinedDynamicDefinition"), "direction"), "kSideways",
        "a combined dynamic the reader can't read: kSideways" },
      { tree.child(tr, firstEvent(tr, "TupletEventDefinition"), "tupletDefinition"),
        "steamVariantList:list: {bool: true}", "has a definition the reader can't read" },
      { tree.path(tr, firstEvent(tr, "ChordSymbolEventDefinition"), "chordSymbolData/primaryChord/root/accidentalType"),
        "kWeird", "has an accidental the reader doesn't know: kWeird" },
    }
    for _, c in ipairs(cases) do refused(t, errorWith(c[1], nil, c[2]), c[3], c[3]) end
  end,
  a_dynamic_of_a_kind_the_reader_doesnt_know = function(t)
    local tr = reading()
    refused(t, errorWith(firstDynamic(tr, "ForceDynamicDefinition"), "FooDynamicDefinition"),
      "holds a FooDynamicDefinition, which the reader doesn't know", "a new dynamic")
  end,
}
