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

-- "<flow>|<player>|<pos>|<spelling>" for every note in the sample, or every note keep(note) is true for.
function checks.noteKeys(keep)
  local keys = {}
  for n, flow in ipairs(checks.expected().flows) do
    for _, player in ipairs(flow.players) do
      for _, note in ipairs(player.notes) do
        if not keep or keep(note) then
          keys[#keys + 1] = table.concat({ n, player.name, tostring(note.pos), note.spelling }, "|")
        end
      end
    end
  end
  return keys
end

-- The keys of every note in the sample higher than spelling (sounding pitch).
function checks.notesAbove(spelling)
  local midi = checks.helper("examples/fundamentals/12-select-by-id.lua", { "midi" }, "midi")
  return checks.noteKeys(function(note) return midi(note.spelling) > midi(spelling) end)
end

-- What 04-read-the-saved-copy.lua printed: its note lines as {key, player, pos, spelling, notehead, colour, line},
-- the key as checks.noteKeys makes it; the format line's columns; and every other line.
function checks.noteLines(run)
  local notes, format, others = {}, nil, {}
  for _, line in ipairs(run.printed) do
    local f = checks.fields(line)
    if f[1] == "format" and not format then
      format = f
    elseif #f == 6 then
      notes[#notes + 1] = { key = table.concat({ f[1], f[2], f[3], f[4] }, "|"), player = f[2], pos = tonumber(f[3]),
        spelling = f[4], notehead = f[5], colour = f[6], line = line }
    else
      others[#others + 1] = line
    end
  end
  return notes, format, others
end

-- True when a note line from checks.noteLines is the sample's styled trumpet note.
function checks.isStyled(note)
  local styled = checks.expected().styled
  return note.player == styled.player and note.pos == styled.pos
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

return checks
