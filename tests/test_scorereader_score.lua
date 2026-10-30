-- The whole score as plain tables, checked against what the fixtures were built from (reading.expected.json and
-- expected.json), and for consistency on the projects older Dorico versions saved.
local score = require("scorereader.score")
local values = require("scorereader.values")
local tree = require("scorereader.tree")
local notes = require("scorereader.read.notes")
local xml = require("scorereader.xml")
local json = require("json")

local here = debug.getinfo(1, "S").source:match("^@(.*[/\\])") or "./"
local fixtures = here .. "../fixtures/"

local function readJson(path)
  local f = assert(io.open(path, "rb"))
  local v = json.decode(f:read("*a"))
  f:close()
  return v
end

local cache = {}
local function load(path)
  cache[path] = cache[path] or score.readFile(fixtures .. path)
  return cache[path]
end

local function pos(p) return values.positionText(p) end

-- {"spelling|pos|duration|grace"} for every note of a player in a flow, sorted.
local function noteKeys(s, flow, player)
  local out = {}
  for _, e in ipairs(score.eventsOf(s, flow, player)) do
    if e.kind == "note" or e.kind == "grace" then
      out[#out + 1] = table.concat({ e.spelling, pos(e.position), e.kind == "grace" and "" or pos(e.duration),
        tostring(e.kind == "grace") }, "|")
    end
  end
  table.sort(out)
  return out
end

local function expectedKeys(notes, asNumbers)
  local out = {}
  for _, n in ipairs(notes) do
    local p = asNumbers and tostring(n.pos) or n.pos
    local d = n.grace and "" or (asNumbers and tostring(n.duration) or n.duration)
    out[#out + 1] = table.concat({ n.spelling, p, d, tostring(n.grace) }, "|")
  end
  table.sort(out)
  return out
end

local function find(list, fn)
  for _, x in ipairs(list) do if fn(x) then return x end end
end

local function events(s, kind)
  local out = {}
  for _, flow in ipairs(s.flows) do
    for _, e in ipairs(flow.events) do
      if e.kind == kind then out[#out + 1] = e end
    end
  end
  return out
end

-- Changes to a decoded tree, for shapes no fixture has: a new value or a new name for one node.
local function setValue(t, id, v)
  t.values[#t.values + 1] = v
  t.valueOf[id] = #t.values - 1
end

local function rename(t, id, name)
  t.names[#t.names + 1] = name
  t.nameIndex[name] = #t.names - 1
  t.nameOf[id] = #t.names - 1
end

-- A new node; its id. A name the tree has keeps its index, so tree.child still finds the nodes that had it.
local function addNode(t, name, value, kids)
  local id = t.count
  t.count = id + 1
  if not t.nameIndex[name] then
    t.names[#t.names + 1] = name
    t.nameIndex[name] = #t.names - 1
  end
  t.nameOf[id] = t.nameIndex[name]
  setValue(t, id, value or "")
  t.kidsOf[id] = kids
  return id
end

-- A kNoteSpelling entry for every layout, from offset quarter notes into the note.
local function spellingEntry(t, letter, offset)
  return addNode(t, "entry", nil, {
    addNode(t, "propertyType", "kNoteSpelling"),
    addNode(t, "value", 'string: "' .. letter .. '"'),
    addNode(t, "context", nil, {
      addNode(t, "layoutIDWithFrameChainID", "steamVariantList:list: {int: -1}, {int: -1}, {bool: false}"),
      addNode(t, "blockInstanceID", "-1"),
      addNode(t, "propertyOffset", 'string: "0:' .. offset .. ':1:0"'),
    }),
  })
end

-- The reading fixture's first chord symbol, read again after change(tree, its chordSymbolData node).
local function changedChord(change)
  local s = score.readFile(fixtures .. "6.2.30/reading.dorico")
  change(s.tree, tree.path(s.tree, events(s, "chordSymbol")[1].node, "chordSymbolData"))
  return events(score.read(s.tree), "chordSymbol")[1]
end

-- The element an event of the reading fixture points to, in the score s read from tree.
local function elementOf(s, e, idField, tableName)
  local id = tonumber(tree.value(s.tree, tree.child(s.tree, e.node, idField)))
  for _, flow in ipairs(s.flows) do
    if flow.id == e.flowId then return flow.elements[tableName][id] end
  end
end

-- The reading fixture's first key signature, read again after change(tree, its keySignature node).
local function changedKey(change)
  local s = score.readFile(fixtures .. "6.2.30/reading.dorico")
  local el = elementOf(s, events(s, "keySignature")[1], "tonalityDivisionElementID",
    "TonalityDivisionElementTableDefinition")
  change(s.tree, tree.path(s.tree, el, "tonalityDivisionData/keySignature"))
  return events(score.read(s.tree), "keySignature")[1]
end

local function keyOf(mode, letter, accidental)
  return changedKey(function(tr, key)
    setValue(tr, tree.path(tr, key, "root/tonalityType"), mode)
    setValue(tr, tree.path(tr, key, "root/root/noteName"), letter)
    setValue(tr, tree.path(tr, key, "root/root/accidentalID"), "accidental.12et.western." .. accidental)
  end)
end

-- A score with one empty flow, no players and no layouts: every list the reader walks is there, and empty.
local EMPTY_SCORE = "<kScore><fileVersion>1.1452</fileVersion><info><title>Empty</title>"
  .. "<lastSavedVersion>6.2.30</lastSavedVersion></info>"
  .. '<library><instruments><entities array="true"/></instruments></library><flows><array array="true"><flow>'
  .. "<flowID>0</flowID><flowName>Flow 1</flowName><flowInfo/>"
  .. '<flowPlayers><array array="true"/></flowPlayers><eventStreams><array array="true"/></eventStreams>'
  .. '<blocks><array array="true"/></blocks><blockInstances><array array="true"/></blockInstances>'
  .. '<elementTables><array array="true"/></elementTables></flow></array></flows>'
  .. '<scorePlayers><array array="true"/></scorePlayers><layouts><array array="true"/></layouts></kScore>'

-- The empty score with one voice stream (5) and one block (9) holding a rest at 1, the block played twice: instance 20
-- at 8 and instance 21 at 0.
local BLOCK_PLAYED_TWICE = EMPTY_SCORE
  :gsub('<eventStreams><array array="true"/></eventStreams>', '<eventStreams><array array="true"><stream>'
    .. "<streamID>5</streamID><eventStreamType>kVoiceStream</eventStreamType></stream></array></eventStreams>")
  :gsub('<blocks><array array="true"/></blocks>', '<blocks><array array="true"><block><blockID>9</blockID>'
    .. '<events array="true"><RestEventDefinition><eventID>100</eventID><position>1</position>'
    .. "<duration>1</duration></RestEventDefinition></events></block></array></blocks>")
  :gsub('<blockInstances><array array="true"/></blockInstances>', '<blockInstances><array array="true">'
    .. "<instance><blockInstanceID>20</blockInstanceID><blockID>9</blockID><streamID>5</streamID>"
    .. "<position>8</position></instance><instance><blockInstanceID>21</blockInstanceID><blockID>9</blockID>"
    .. "<streamID>5</streamID><position>0</position></instance></array></blockInstances>")

-- The ids of the streams the index-th flow's condensedStreams lists, which belong to no one player.
local function condensedStreamIds(s, index)
  local t, out = s.tree, {}
  local function walk(n)
    if tree.name(t, n):find("StreamID$") then out[tonumber(tree.value(t, n))] = true end
    for _, k in ipairs(tree.children(t, n)) do walk(k) end
  end
  local condensed = tree.child(t, tree.children(t, tree.path(t, 0, "flows/array"))[index], "condensedStreams")
  if condensed then walk(condensed) end
  return out
end

local CHORD_SUFFIX = { major = "", dominant = "7", minor = "m" }
local SYLLABLES = { begin = "begin", middle = "middle", ["end"] = "end", single = "single" }

return {
  info_flows_and_players = function(t)
    local s = load("6.2.30/reading.dorico")
    local want = readJson(fixtures .. "reading.expected.json")
    t:eq(s.format.fileVersion, "1.1452")
    t:eq(s.info.title, "Reading")
    t:eq(#s.flows, 2)
    t:eq(s.flows[1].title, want.flows[1].title)
    t:eq(s.flows[2].title, want.flows[2].title)
    for i, p in ipairs(want.flows[1].players) do t:eq(s.players[i].name, p.name) end
  end,
  every_note_of_the_reading_fixture = function(t)
    local s = load("6.2.30/reading.dorico")
    local want = readJson(fixtures .. "reading.expected.json")
    for fi, flow in ipairs(want.flows) do
      for pi, player in ipairs(flow.players) do
        t:eq(table.concat(noteKeys(s, s.flows[fi], s.players[pi]), " "),
          table.concat(expectedKeys(player.notes), " "), "flow " .. fi .. " " .. player.name)
      end
    end
  end,
  every_note_of_the_sample = function(t)
    local s = load("6.2.30/sample.dorico")
    local want = readJson(fixtures .. "expected.json")
    for fi, flow in ipairs(want.flows) do
      for pi, player in ipairs(flow.players) do
        local got = {}
        for _, k in ipairs(noteKeys(s, s.flows[fi], s.players[pi])) do
          local sp, p, d, g = k:match("^(.-)|(.-)|(.-)|(.-)$")
          local num = function(x) return x ~= "" and tostring(values.toNumber(values.position(x))) or "" end
          got[#got + 1] = table.concat({ sp, num(p), num(d), g }, "|")
        end
        table.sort(got)
        t:eq(table.concat(got, " "), table.concat(expectedKeys(player.notes, true), " "), player.name)
      end
    end
  end,
  non_ascii_names_come_back_exactly = function(t)
    local s = load("6.2.30/sample.dorico")
    local want = readJson(fixtures .. "expected.json")
    t:eq(s.players[2].name, want.flows[1].players[2].name, "Zoë, as UTF-8, with Dorico's flat token")
    t:eq(s.players[2].name, "Trumpet Zo\195\171 (B{@flat@})")
    local lilacs = load("6.0.22/Novello_Lilacs.dorico")
    t:eq(lilacs.info.title, "WE\226\128\153LL GATHER LILACS", "a curly apostrophe")
    t:eq(lilacs.events[1626].text, "We\226\128\153ll")
    local dolly = load("6.2.20/Faure_Dolly.dorico")
    t:eq(dolly.info.composer, "Gabriel FAUR\195\137")
    t:eq(dolly.events[10695].text, "Pi\195\185  Lento")
  end,
  a_tied_note_respelled_partway_keeps_its_first_spelling = function(t)
    local e = load("6.2.20/Faure_Dolly.dorico").events[8297]
    t:eq(e.spelling, "E#4", "the dump's spelling; the tied part from beat 120 is spelled F")
  end,
  a_later_spelling_is_left_out_whichever_comes_first = function(t)
    for _, laterFirst in ipairs({ false, true }) do
      local s = score.readFile(fixtures .. "6.2.30/reading.dorico")
      local e = find(events(s, "note"), function(x) return x.spelling == "C5" end)
      local entries = tree.path(s.tree, e.node, "propertyTable/entries")
      local later = spellingEntry(s.tree, "B", 2)
      local kids = { table.unpack(tree.children(s.tree, entries)) }
      table.insert(kids, laterFirst and 1 or #kids + 1, later)
      s.tree.kidsOf[entries] = kids
      t:eq(score.read(s.tree).events[e.id].spelling, "C5", laterFirst and "the later one listed first" or "listed last")
    end
  end,
  grace_notes = function(t)
    local s = score.readFile(fixtures .. "6.2.30/reading.dorico")
    local g = events(s, "grace")[1]
    t:eq(pos(g.notatedDuration), "1/2")
    t:eq(g.slashed, true)
    setValue(s.tree, tree.child(s.tree, g.node, "slashed"), "false")
    t:eq(score.read(s.tree).events[g.id].slashed, false)
  end,
  spellings_as_the_dump_writes_them = function(t)
    t:eq(notes.spelling("D", 64), "Dx4", "a double sharp is x")
    t:eq(notes.spelling("E", 62), "Ebb4")
    t:eq(notes.spelling("B", 60), "B#3", "the octave goes with the letter")
    t:eq(notes.spelling("C", 59), "Cb4")
  end,
  texts_with_their_words = function(t)
    local s = load("6.2.30/reading.dorico")
    for _, want in ipairs(readJson(fixtures .. "reading.expected.json").texts) do
      local e = find(events(s, "text"), function(x) return pos(x.position) == want.pos and x.words == want.words end)
      t:ok(e, "text " .. want.words)
      t:eq(e.above, want.above, want.words)
      t:eq(e.system, false)
      t:eq(e.paragraphs[1].style, "paragraph.defaulttext")
      t:eq(e.formatted, false)
    end
  end,
  system_text_paragraphs_and_formatting = function(t)
    local s = score.readFile(fixtures .. "6.2.30/reading.dorico")
    local tr, e = s.tree, events(s, "text")[1]
    setValue(tr, tree.child(tr, e.node, "isSystemText"), "true")
    local paragraphs = tree.path(tr, e.node, "content/paragraphs")
    local p = tree.children(tr, paragraphs)[1]
    tr.kidsOf[paragraphs] = { p, p }
    local again = score.read(tr).events[e.id]
    t:eq(again.system, true)
    t:eq(#again.paragraphs, 2)
    t:eq(again.words, e.words .. "\n" .. e.words, "paragraphs joined by a newline")
    t:eq(again.formatted, false, "one plain fragment in each")
    local fragments = tree.child(tr, p, "fragments")
    local f = tree.children(tr, fragments)[1]
    tr.kidsOf[fragments] = { f, f }
    t:eq(score.read(tr).events[e.id].formatted, true, "two fragments in a paragraph")
  end,
  lyrics_with_syllables_and_lines = function(t)
    local s = load("6.2.30/reading.dorico")
    for _, want in ipairs(readJson(fixtures .. "reading.expected.json").lyrics) do
      local e = find(events(s, "lyric"), function(x)
        return pos(x.position) == want.pos and x.text == want.text end)
      t:ok(e, "lyric " .. want.text)
      t:eq(e.syllable, SYLLABLES[want.syllable], want.text)
      t:eq(e.line, want.line, want.text)
      t:eq(e.duration.num > 0, want.extend, want.text .. " melisma")
      t:eq(e.lineType, "verse", want.text)
      t:eq(e.above, false, want.text)
    end
  end,
  a_chorus_lyric_above_the_staff = function(t)
    local s = score.readFile(fixtures .. "6.2.30/reading.dorico")
    local e = events(s, "lyric")[1]
    local el = elementOf(s, e, "lyricElementID", "LyricElementTableDefinition")
    setValue(s.tree, tree.child(s.tree, el, "lineType"), "kChorus")
    setValue(s.tree, tree.child(s.tree, el, "lineLocation"), "kAbove")
    local again = score.read(s.tree).events[e.id]
    t:eq(again.lineType, "chorus")
    t:eq(again.above, true)
  end,
  chord_symbols = function(t)
    local s = load("6.2.30/reading.dorico")
    local got = events(s, "chordSymbol")
    for i, want in ipairs(readJson(fixtures .. "reading.expected.json").chords) do
      t:eq(pos(got[i].position), want.pos)
      t:eq(got[i].root, want.root)
      t:eq(got[i].name, want.root .. CHORD_SUFFIX[want.chord])
    end
  end,
  chord_names_only_for_shapes_checked_against_dorico = function(t)
    local minorMajor = changedChord(function(tr, data)
      setValue(tr, tree.path(tr, data, "primaryChord/definition/quality"), "kMinor")
      setValue(tr, tree.path(tr, data, "primaryChord/definition/interval"), "kMaj7")
    end)
    t:eq(minorMajor.quality, "minor")
    t:eq(minorMajor.interval, "maj7")
    t:eq(minorMajor.name, nil, "not Cmmaj7")
    t:eq(changedChord(function(tr, data)
      setValue(tr, tree.path(tr, data, "primaryChord/definition/customChordName"), "C(add9)")
    end).name, nil, "a custom name")
    t:eq(changedChord(function(tr, data)
      setValue(tr, tree.path(tr, data, "playedSecondaryPitches"), "steamVariantList:list: {int: 52}")
    end).name, nil, "secondary pitches")
    local bass = changedChord(function(tr, data)
      rename(tr, tree.path(tr, data, "playedSecondaryPitches"), "bassNote")
    end)
    t:eq(bass.root, "C", "the root still comes back")
    t:eq(bass.name, nil, "a node the reader hasn't seen")
  end,
  dynamics_by_name = function(t)
    local s = load("6.2.30/reading.dorico")
    local got = {}
    for _, e in ipairs(events(s, "dynamic")) do
      for _, d in ipairs(e.dynamics) do
        got[#got + 1] = score.ownerOf(s, e).name .. "|" .. pos(d.position) .. "|" .. d.name
      end
    end
    local wanted = readJson(fixtures .. "reading.expected.json")
    for _, want in ipairs(wanted.dynamics) do
      local key = want.player .. "|" .. want.pos .. "|" .. want.name
      t:ok(find(got, function(x) return x == key end), key .. " in " .. table.concat(got, ", "))
    end
    t:ok(find(got, function(x) return x == "Flute|12|crescendo" end), "the hairpin")
  end,
  a_diminuendo_and_messa_di_voce = function(t)
    local function hairpinWith(field, v)
      local s = score.readFile(fixtures .. "6.2.30/reading.dorico")
      local e = find(events(s, "dynamic"), function(x)
        return find(x.dynamics, function(d) return d.kind == "gradual" end) end)
      local el = elementOf(s, e, "dynamicGroupID", "DynamicGroupElementTableDefinition")
      local sub = find(tree.children(s.tree, tree.child(s.tree, el, "subElements")), function(n)
        return tree.name(s.tree, n) == "GradualChangeDynamicDefinition" end)
      setValue(s.tree, tree.child(s.tree, sub, field), v)
      return find(score.read(s.tree).events[e.id].dynamics, function(d) return d.kind == "gradual" end)
    end
    t:eq(hairpinWith("direction", "kGradualDynamicDown").name, "diminuendo")
    t:eq(hairpinWith("type", "kMessaDiVoce").name, "messa di voce")
  end,
  keys_and_time_signatures = function(t)
    local s = load("6.2.30/reading.dorico")
    local want = readJson(fixtures .. "reading.expected.json")
    local keys, times = events(s, "keySignature"), events(s, "timeSignature")
    for i, k in ipairs(want.keys) do
      t:eq(pos(keys[i].position), k.pos)
      t:eq(keys[i].fifths, k.fifths)
      t:eq(keys[i].mode, "major")
    end
    for i, x in ipairs(want.times) do
      t:eq(pos(times[i].position), x.pos)
      t:eq(times[i].numerator, x.beats)
      t:eq(times[i].denominator, x.beatType)
    end
  end,
  minor_and_flat_keys = function(t)
    local bFlat = keyOf("kKeySigMajor", "B", "flat")
    t:eq(bFlat.root, "Bb")
    t:eq(bFlat.fifths, -2)
    local gMinor = keyOf("kKeySigMinor", "G", "natural")
    t:eq(gMinor.mode, "minor")
    t:eq(gMinor.fifths, -2)
    t:eq(keyOf("kKeySigMinor", "F", "sharp").fifths, 3, "F sharp minor")
    t:eq(keyOf("kKeySigMajor", "C", "flat").fifths, -7, "C flat major")
  end,
  a_key_in_another_tonality_system_has_no_root = function(t)
    local e = changedKey(function(tr, key)
      setValue(tr, tree.path(tr, key, "root/root/accidentalID"), "accidental.24et.western.flat.gould")
    end)
    t:eq(e.mode, "major")
    t:eq(e.accidentalID, "accidental.24et.western.flat.gould")
    t:eq(e.root, nil, "not the bare letter")
    t:eq(e.fifths, nil)
  end,
  a_bar_division_with_no_time_signature = function(t)
    local s = score.readFile(fixtures .. "6.2.30/reading.dorico")
    local el = elementOf(s, events(s, "timeSignature")[1], "barDivisionElementID", "BarDivisionElementTableDefinition")
    s.tree.kidsOf[tree.path(s.tree, el, "barDivisionData/timeSignature/timeSignaturesAndDivisions")] = {}
    local e = events(score.read(s.tree), "timeSignature")[1]
    t:eq(e.barlineOnly, true)
    t:eq(e.numerator, nil)
  end,
  tuplets_tempos_marks_and_techniques = function(t)
    local s = load("6.2.30/reading.dorico")
    local want = readJson(fixtures .. "reading.expected.json")
    local tuplet = events(s, "tuplet")[1]
    t:eq(pos(tuplet.position), want.tuplets[1].pos)
    t:eq(tuplet.actual, 3)
    t:eq(tuplet.normal, 2)
    local tempo = events(s, "tempo")[1]
    t:eq(tempo.text, "Allegro")
    t:eq(tempo.bpm, 120)
    t:eq(pos(events(s, "rehearsalMark")[1].position), want.rehearsalMarks[1].pos)
    local techniques = events(s, "playingTechnique")
    t:eq(#techniques, 2)
    t:eq(techniques[1].text, "pizz")
    t:eq(techniques[1].name, "Pizzicato")
    t:eq(techniques[2].text, "arco")
  end,
  note_properties_where_they_apply = function(t)
    local s = load("6.2.30/reading.dorico")
    local fullScore = s.layouts[1].id
    for _, want in ipairs(readJson(fixtures .. "reading.expected.json").props) do
      local player = find(s.players, function(p) return p.name == want.player end)
      local e = find(score.eventsOf(s, s.flows[1], player), function(x)
        return x.kind == "note" and pos(x.position) == want.pos and x.spelling == want.spelling end)
      t:ok(e, want.player .. " " .. want.spelling)
      local layout = fullScore
      if want.how == "part" then layout = score.partOf(s, player).id end
      local v = score.value(s, e, want.property, layout)
      t:eq(v, want.value, want.player .. " " .. want.property .. " (" .. want.how .. ")")
      if want.how == "part" then
        t:eq(score.value(s, e, want.property, fullScore), nil, "not in the full score")
      end
    end
  end,
  a_value_set_for_another_block_instance = function(t)
    -- a score of its own, since this changes the cache
    local s = score.readFile(fixtures .. "6.2.30/reading.dorico")
    local e = find(s.flows[1].events, function(x) return x.kind == "note" end)
    local function valueWith(entry)
      s.cache[e] = { entry }
      return score.value(s, e, "kEventColour", s.layouts[1].id)
    end
    local function entry(instance, value)
      return { property = "kEventColour", value = value, layout = -1, frameChain = -1, instance = instance }
    end
    local v, elsewhere = valueWith(entry(e.instanceId + 1000, 'string: "#ff0000ff"'))
    t:eq(v, nil, "no value here")
    t:eq(elsewhere, true, "but one for another instance")
    v, elsewhere = valueWith(entry(e.instanceId, 'string: "#ff0000ff"'))
    t:eq(v, "#ff0000ff")
    t:eq(elsewhere, false)
    v, elsewhere = valueWith(entry(-1, "null: "))
    t:eq(v, nil, "a null value reads as unset")
    t:eq(elsewhere, false)
  end,
  articulations_and_strings = function(t)
    local s = load("6.2.30/reading.dorico")
    local flute = score.eventsOf(s, s.flows[1], s.players[1])
    local c5 = find(flute, function(x) return x.kind == "note" and pos(x.position) == "0" end)
    t:eq(score.value(s, c5, "kArticulationDuration", s.layouts[1].id), "kStaccato")
    local guitar = score.eventsOf(s, s.flows[1], s.players[3])
    local first = find(guitar, function(x) return x.kind == "note" and pos(x.position) == "0" end)
    t:eq(score.value(s, first, "kNoteStringIndex", s.layouts[1].id), 4, "the fifth string, counted from 0")
  end,
  a_piano_has_a_stream_for_each_staff = function(t)
    local s = load("6.2.30/reading.dorico")
    local piano = find(s.players, function(p) return p.name == "Piano" end)
    local staves = {}
    for _, stream in ipairs(s.flows[1].streams) do
      if stream.type == "stave" and stream.playerId == piano.id then staves[#staves + 1] = stream.staff end
    end
    table.sort(staves)
    t:eq(table.concat(staves, ","), "0,1")
  end,
  a_players_events_in_time_order = function(t)
    local s = load("6.2.30/reading.dorico")
    for _, p in ipairs(s.players) do
      local list = score.eventsOf(s, s.flows[1], p)
      t:ok(#list > 1, p.name)
      for i = 2, #list do
        local a, b = list[i - 1], list[i]
        local x, y = values.toNumber(a.position), values.toNumber(b.position)
        t:ok(x < y or (x == y and a.id < b.id), p.name .. ": " .. a.id .. " before " .. b.id)
      end
      for _, e in ipairs(list) do t:eq(score.ownerOf(s, e), p, p.name .. " owns " .. e.id) end
    end
  end,
  a_block_played_twice = function(t)
    local s = score.read(xml.decode(BLOCK_PLAYED_TWICE))
    local stream = s.flows[1].streamById[5]
    t:eq(#stream.instances, 2)
    t:eq(stream.instances[1].id, 21, "instances in time order")
    t:eq(#stream.events, 2, "the rest once for each instance")
    t:eq(stream.events[1].id, 100)
    t:eq(stream.events[2].id, 100, "with the same id")
    t:eq(pos(stream.events[1].position), "1")
    t:eq(stream.events[1].instanceId, 21)
    t:eq(pos(stream.events[2].position), "9")
    t:eq(stream.events[2].instanceId, 20)
    t:eq(s.events[100], stream.events[1], "s.events holds the first")
    t:eq(#s.flows[1].events, 2)
  end,
  instruments = function(t)
    local s = load("6.2.30/reading.dorico")
    local clarinet = s.players[2].instruments[1]
    t:eq(clarinet.entityID, "instrument.wind.clarinet.bflat")
    t:eq(clarinet.transposition.diatonic, 1)
    t:eq(clarinet.transposition.chromatic, 2)
    t:eq(clarinet.range.standard, "D3-F6")
    t:eq(s.instruments[clarinet.id], clarinet)
  end,
  layouts_and_parts = function(t)
    local s = load("6.2.30/reading.dorico")
    t:eq(#s.layouts, 7)
    t:eq(s.layouts[1].type, "kFullScoreLayout")
    t:eq(#s.layouts[1].playerIds, 6)
    t:eq(score.partOf(s, s.players[1]).playerIds[1], s.players[1].id)
    t:eq(score.fullScoreOf(s), s.layouts[1])
  end,
  a_score_with_no_full_score_layout = function(t)
    local s = { layouts = { { id = 3, type = "kPartLayout" }, { id = 4, type = "kPartLayout" } } }
    t:eq(score.fullScoreOf(s), nil)
  end,
  an_empty_score_reads_cleanly = function(t)
    local s = score.read(xml.decode(EMPTY_SCORE))
    t:eq(s.info.title, "Empty")
    t:eq(#s.flows, 1)
    t:eq(s.flows[1].title, "Flow 1")
    t:eq(#s.flows[1].streams, 0)
    t:eq(#s.flows[1].events, 0)
    t:eq(#s.players, 0)
    t:eq(#s.layouts, 0)
  end,
  events_and_flows_by_id = function(t)
    local s = load("6.2.30/reading.dorico")
    local e = s.flows[1].events[1]
    t:eq(s.events[e.id], e)
    t:ok(e.streamId and e.instanceId and e.blockId, "where it lives")
    for _, f in ipairs(s.flows) do t:eq(s.flowById[f.id], f, "flow " .. f.id) end
  end,
  a_timebase_event_has_no_owner = function(t)
    local s = load("6.2.30/reading.dorico")
    local flow, timebase = s.flows[1], nil
    for _, e in ipairs(flow.events) do
      if not timebase and flow.streamById[e.streamId].type == "timebase" then timebase = e end
    end
    t:ok(timebase, "the flow has a timebase event")
    t:eq(score.ownerOf(s, timebase), nil)
  end,
  older_projects_read_consistently = function(t)
    for _, entry in ipairs(readJson(fixtures .. "versions.json")) do
      local s = load(entry.path)
      t:ok(#s.flows > 0, entry.path)
      local notes = 0
      for fi, flow in ipairs(s.flows) do
        local condensed = condensedStreamIds(s, fi)
        for _, e in ipairs(flow.events) do
          local where = entry.path .. " event " .. e.id
          t:ok(e.kind and e.definition, where)
          local stream = flow.streamById[e.streamId]
          t:ok(stream, where .. " is in a stream")
          if stream.type ~= "timebase" and stream.type ~= "automation" and not condensed[stream.id] then
            t:ok(score.ownerOf(s, e), where .. " has an owner")
          end
          t:ok(e.position.den > 0 and e.duration.num >= 0, where .. " position and duration")
          if e.kind == "note" or e.kind == "grace" then
            notes = notes + 1
            t:ok(e.pitch >= 0 and e.pitch <= 127, where .. " pitch " .. e.pitch)
            t:ok(e.spelling:match("^[A-G][#bx]*%-?%d$"), where .. " spelling " .. tostring(e.spelling))
          end
          if e.kind == "text" then t:eq(type(e.words), "string", where .. " words") end
          if e.kind == "lyric" then t:ok(e.text and e.syllable and e.lineType, where .. " lyric") end
          if e.kind == "chordSymbol" then t:ok(e.root:match("^[A-G]"), where .. " chord root " .. e.root) end
          if e.kind == "dynamic" then t:ok(#e.dynamics > 0, where .. " dynamics") end
          if e.kind == "timeSignature" then t:ok(e.numerator or e.barlineOnly, where .. " time") end
          if e.kind == "keySignature" then t:ok(e.root or e.atonal, where .. " key") end
          if e.kind == "tempo" then t:ok(e.type, where .. " tempo type") end
          if e.kind == "tuplet" then t:ok(e.actual > 0 and e.normal > 0, where .. " tuplet") end
          t:ok(score.entries(s, e), where .. " properties")
        end
      end
      t:ok(notes > 0, entry.path .. " has notes")
    end
  end,
}
