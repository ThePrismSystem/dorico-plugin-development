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

-- The reading fixture's first chord symbol, read again after change(tree, its chordSymbolData node).
local function changedChord(change)
  local s = score.readFile(fixtures .. "6.2.30/reading.dorico")
  change(s.tree, tree.path(s.tree, events(s, "chordSymbol")[1].node, "chordSymbolData"))
  return events(score.read(s.tree), "chordSymbol")[1]
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
    end
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
    end
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
  articulations_and_strings = function(t)
    local s = load("6.2.30/reading.dorico")
    local flute = score.eventsOf(s, s.flows[1], s.players[1])
    local c5 = find(flute, function(x) return x.kind == "note" and pos(x.position) == "0" end)
    t:eq(score.value(s, c5, "kArticulationDuration", s.layouts[1].id), "kStaccato")
    local guitar = score.eventsOf(s, s.flows[1], s.players[3])
    local first = find(guitar, function(x) return x.kind == "note" and pos(x.position) == "0" end)
    t:eq(score.value(s, first, "kNoteStringIndex", s.layouts[1].id), 4, "the fifth string, counted from 0")
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
  events_by_id = function(t)
    local s = load("6.2.30/reading.dorico")
    local e = s.flows[1].events[1]
    t:eq(s.events[e.id], e)
    t:ok(e.streamId and e.instanceId and e.blockId, "where it lives")
  end,
  older_projects_read_consistently = function(t)
    for _, entry in ipairs(readJson(fixtures .. "versions.json")) do
      local s = load(entry.path)
      t:ok(#s.flows > 0, entry.path)
      local notes = 0
      for _, flow in ipairs(s.flows) do
        for _, e in ipairs(flow.events) do
          t:ok(e.kind and e.definition, entry.path .. " event " .. e.id)
          if e.kind == "note" then
            notes = notes + 1
            t:ok(e.spelling:match("^[A-G][#bx]*%-?%d$"), entry.path .. " spelling " .. tostring(e.spelling))
          end
          if e.kind == "lyric" then t:ok(e.text, entry.path .. " lyric " .. e.id) end
          if e.kind == "dynamic" then t:ok(#e.dynamics > 0, entry.path .. " dynamic " .. e.id) end
          if e.kind == "timeSignature" then t:ok(e.numerator or e.barlineOnly, entry.path .. " time " .. e.id) end
          if e.kind == "keySignature" then t:ok(e.root or e.atonal, entry.path .. " key " .. e.id) end
          t:ok(score.entries(s, e), entry.path .. " properties of " .. e.id)
        end
      end
      t:ok(notes > 0, entry.path .. " has notes")
    end
  end,
}
