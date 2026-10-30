-- Shared pieces for the check files in tests/dorico/checks/.
local checks = {}

local here = debug.getinfo(1, "S").source:match("^@(.*[/\\])")

local function readJson(name)
  local json = require("json")
  local f = assert(io.open(here .. "../../../fixtures/" .. name, "rb"))
  local value = json.decode(f:read("*a"))
  f:close()
  return value
end

-- fixtures/expected.json: what the sample holds.
function checks.expected()
  return readJson("expected.json")
end

-- fixtures/reading.expected.json: what the reading fixture holds.
function checks.reading()
  return readJson("reading.expected.json")
end

-- Any JSON file in fixtures/, by name.
function checks.json(name)
  return readJson(name)
end

-- The open project as the reader sees it, from a saved copy: the score, and the score and values modules.
function checks.savedCopy()
  local lib = here .. "../../../lib/?.lua"
  for name in pairs(package.loaded) do
    if name:match("^scorereader") then package.loaded[name] = nil end
  end
  if not package.path:find(lib, 1, true) then package.path = lib .. ";" .. package.path end
  local s = require("scorereader.dorico.savedcopy").read(DoApp.DoApp())
  return s, require("scorereader.score"), require("scorereader.values")
end

-- {"<flow n>|<player>|<pos>|<spelling>" = event} for every note and grace note of a score the reader read, keyed as
-- checks.notesAbove keys them.
function checks.notesOf(s, score, values)
  local out = {}
  for n, flow in ipairs(s.flows) do
    for _, player in ipairs(s.players) do
      for _, e in ipairs(score.eventsOf(s, flow, player)) do
        if e.kind == "note" or e.kind == "grace" then
          out[table.concat({ n, player.name, tostring(values.toNumber(e.position)), e.spelling }, "|")] = e
        end
      end
    end
  end
  return out
end

-- Loads helper blocks out of an example together (a later block may use an earlier one) and returns the value of
-- the one named want. They are the blocks the examples run, so the checks read the project the way the examples do.
function checks.helper(example, names, want)
  local f = assert(io.open(here .. "../../../" .. example, "rb"))
  local source = f:read("*a")
  f:close()
  local parts = {}
  for _, name in ipairs(names) do
    parts[#parts + 1] = assert(source:match("\n%-%- helper: " .. name .. "\r?\n(.-)\n%-%- end helper: " .. name),
      "no helper " .. name .. " in " .. example)
  end
  return assert(load(table.concat(parts, "\n") .. "\nreturn " .. want, "=" .. example))()
end

-- {[flow number] = title}, from the text export.
function checks.flowTitles()
  local export = checks.helper("examples/fundamentals/15-layout-and-notation-options.lua", { "commands", "export" },
    "export")
  local titles = {}
  for _, rec in ipairs(export.records(DoApp.DoApp(), export.folder(), "checks-flow-titles")) do
    if rec.Type == "Flow Info (Title)" and tonumber(rec.FlowNumber) then titles[tonumber(rec.FlowNumber)] = rec.Text end
  end
  return titles
end

-- Every note's spelling, position and duration, against expected.json: whether the music is as the sample has it.
function checks.musicUnchanged(p)
  local dump = checks.helper("examples/fundamentals/03-read-notes.lua", { "dump" }, "dump")
  local want = checks.expected()
  local score = DoApp.DoApp().currentScore
  for n, flow in ipairs(want.flows) do
    local got, wanted = {}, {}
    for _, stream in ipairs(score.flows[n].voiceStreams) do
      for _, note in ipairs(dump.notes(dump.parse(stream:dump()))) do
        got[#got + 1] = table.concat({ note.spelling, tostring(note.pos), tostring(note.duration) }, "|")
      end
    end
    for _, player in ipairs(flow.players) do
      for _, note in ipairs(player.notes) do
        wanted[#wanted + 1] = table.concat({ note.spelling, tostring(note.pos),
          tostring(not note.grace and note.duration or nil) }, "|")
      end
    end
    p:check("flow " .. n .. "'s notes are as they were", checks.joined(got) == checks.joined(wanted),
      "got " .. checks.joined(got))
  end
end

-- The text events in every voice stream of a flow, as "<pos>|<text>".
function checks.texts(flowNumber)
  local dump = checks.helper("examples/fundamentals/03-read-notes.lua", { "dump" }, "dump")
  local out = {}
  for _, stream in ipairs(DoApp.DoApp().currentScore.flows[flowNumber].voiceStreams) do
    for _, ev in ipairs(dump.parse(stream:dump()).events) do
      if ev.kind == "text" then out[#out + 1] = tostring(ev.pos) .. "|" .. tostring(ev.text) end
    end
  end
  return out
end

-- "<flow>|<player>|<pos>|<spelling>" for every note in the sample higher than spelling (sounding pitch).
function checks.notesAbove(spelling)
  local midi = checks.helper("examples/fundamentals/12-select-by-id.lua", { "midi" }, "midi")
  local keys = {}
  for n, flow in ipairs(checks.expected().flows) do
    for _, player in ipairs(flow.players) do
      for _, note in ipairs(player.notes) do
        if midi(note.spelling) > midi(spelling) then
          keys[#keys + 1] = table.concat({ n, player.name, tostring(note.pos), note.spelling }, "|")
        end
      end
    end
  end
  return keys
end

-- The chord symbols in a flow's timebase stream (stream type 0), as "<pos>|<name>": the dump names each one after its
-- position ("kChordSymbolEvent (id:326) at 12  G7 ...").
function checks.chordSymbols(flowNumber)
  local dump = checks.helper("examples/fundamentals/03-read-notes.lua", { "dump" }, "dump")
  local out = {}
  for _, stream in ipairs(DoApp.DoApp().currentScore.flows[flowNumber].allStreams) do
    if stream.type == 0 then
      for _, ev in ipairs(dump.parse(stream:dump()).events) do
        local name = ev.raw:match("^kChordSymbolEvent %(id:%d+%) at %S+%s+(%S+)")
        if name then out[#out + 1] = tostring(ev.pos) .. "|" .. name end
      end
    end
  end
  return out
end

-- A printed line's tab-separated columns.
function checks.fields(line)
  local out = {}
  for field in (line .. "\t"):gmatch("([^\t]*)\t") do out[#out + 1] = field end
  return out
end

-- The sorted keys of a list, joined, so two sets can be compared as one string.
function checks.joined(keys)
  local copy = {}
  for i, k in ipairs(keys) do copy[i] = k end
  table.sort(copy)
  return table.concat(copy, " ")
end

-- True when the printed lines include this exact line.
function checks.printed(run, line)
  for _, l in ipairs(run.printed) do
    if l == line then return true end
  end
  return false
end

-- The texts fixture's texts, lyrics and chord symbols as the open project has them, and as texts.expected.json says
-- they should be after a row's changes (row.texts, row.lyrics and row.chords: new words by bar), each as one string.
function checks.textsNow(row)
  row = row or {}
  local want = readJson("texts.expected.json")
  local s, score, values = checks.savedCopy()
  local function changed(list, bar, words)
    return list and list[tostring(bar)] or words
  end
  local expected = {}
  for _, t in ipairs(want.texts) do
    expected[#expected + 1] = string.format("text %s|%g|%s|%s|%s", t.player, t.bar, changed(row.texts, t.bar, t.words),
      tostring(t.above), tostring(t.system))
  end
  for _, l in ipairs(want.lyrics) do
    local text = (l.line == 1 and l.beat == 1) and changed(row.lyrics, l.bar, l.text) or l.text
    expected[#expected + 1] = string.format("lyric %g|%g|%d|%s|%s", l.bar, l.beat, l.line, text, l.syllable)
  end
  for _, c in ipairs(want.chords) do
    expected[#expected + 1] = string.format("chord %g|%s", c.bar, changed(row.chords, c.bar, c.name))
  end
  local now = {}
  for _, e in ipairs(s.flows[1].events) do
    local pos = values.toNumber(e.position)
    local bar, beat = math.floor(pos / 4) + 1, pos % 4 + 1
    if e.kind == "text" then
      local owner = score.ownerOf(s, e)
      now[#now + 1] = string.format("text %s|%g|%s|%s|%s", owner and owner.name or "-", bar, e.words,
        tostring(score.above(s, e, s.layouts[1].id)), tostring(e.system))
    elseif e.kind == "lyric" then
      now[#now + 1] = string.format("lyric %g|%g|%d|%s|%s", bar, beat, e.line, e.text, e.syllable)
    elseif e.kind == "chordSymbol" then
      now[#now + 1] = string.format("chord %g|%s", bar, tostring(e.name))
    end
  end
  return checks.joined(now), checks.joined(expected)
end

return checks
