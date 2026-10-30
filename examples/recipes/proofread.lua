-- Recipe: a proofreading report. Lists notes outside their instrument's range, and parallel fifths and octaves between
-- the voices of one player (a piano's two hands, say), without changing the music.
-- What it does: prints one line per finding, "<flow> bar <n> beat <b>: <finding>", then how many it found.
-- Changes: nothing that stays. It makes marker texts to read instrument names and bar numbers from the text export,
-- and deletes them again.
-- Undo: nothing to undo. The markers still make an undo step, so Edit > Undo straight after this script changes
-- nothing you can see; a second press reaches your own last edit.
-- Builds on: 03-read-notes.lua, 05-names-from-the-text-export.lua and 12-select-by-id.lua (the midi helper). Open
-- Script > Show Script Console to read what it prints.
--
-- Ranges are by instrument, and Lua can't name an instrument, so the script puts a marker text in each voice and reads
-- the instrument's name off the marker's row in the text export, as 05-names-from-the-text-export.lua does. RANGES
-- below matches the start of that name: "Trumpet" covers "Trumpet in Bb" and "Trumpet Zoë". Its ranges are sounding
-- pitches, wide enough for a confident player; narrow them for young players.
--
-- Lua can't read time signatures either, so it can't count bars. The export can: every text's row has the bar it's
-- in. For each finding the script puts markers at the finding and at each of the sixteen quarter notes before it, and
-- exports, which finds the first whole quarter note in the finding's bar. A second round of markers, every 1/24 of a
-- quarter note in the gap before that, finds where the bar really starts, which can be between quarter notes after a
-- pickup or in 3/8. Beats are counted in quarter notes from there, so in 6/8 the second dotted-quarter beat shows as
-- beat 2.5. A bar longer than sixteen quarter notes gives a beat counted from a later point.
--
-- The parallels check compares the top note of each voice wherever either voice moves, and reports two voices that
-- both move the same way from a fifth to a fifth, or from an octave (or unison) to an octave. It doesn't look across
-- players, and a voice's chords count only by their top note.
--
-- Nothing here looks for incomplete bars. A bar whose rests were removed looks the same to a script as a bar of
-- implicit rests (docs/spikes.md, S3).

local RANGES = { -- {start of the instrument's name, lowest, highest}, sounding
  { "Piccolo", "D5", "C8" }, { "Flute", "C4", "C7" }, { "Oboe", "Bb3", "G6" }, { "Clarinet", "D3", "Bb6" },
  { "Bassoon", "Bb1", "Eb5" }, { "Horn", "B1", "F5" }, { "Trumpet", "E3", "Bb5" }, { "Trombone", "E2", "F5" },
  { "Tuba", "D1", "F4" }, { "Violin", "G3", "A7" }, { "Viola", "C3", "E6" }, { "Cello", "C2", "A5" },
  { "Double Bass", "E1", "G4" }, { "Contrabass", "E1", "G4" }, { "Piano", "A0", "C8" },
}

-- helper: guard
-- The app and the open project, or the app and nil when no project is open. The read of app.currentScore goes
-- through pcall in case it raises an error then instead of giving nil, which no run here has checked.
local function guard()
  local app = DoApp.DoApp()
  local ok, score = pcall(function() return app.currentScore end)
  if ok and score then return app, score end
  print("Open a project first, then run this script again.")
  return app, nil
end
-- end helper: guard

-- helper: dump
-- stream:dump() as tables. Each event line reads "<pos> (<pos>)[ dur: <d>]: <event>", where <event> is what
-- tostring(event) gives, such as "kNoteEvent (id:7932) at 0, duration 1  E5 (ends 1)". A "Start block id:" line
-- starts each block instance; the events after it belong to that instance (EventEdit.Select needs it).
--   dump.parse(text) -> {events = {{kind, id, pos, duration, spelling, grace, instance, raw}}}
--   dump.event(text, instance) -> one event from tostring(event), or nil
--   dump.notes(parsed) -> the notes and grace notes, {{id, spelling, pos, duration, grace, instance}}
--   dump.owners(score, flow) -> {[voice stream id] = player name}
-- Kinds are "note", "grace", "rest", "text" and "other". Positions and durations are quarter notes.
local dump = {}
do
  local KINDS = {
    kNoteEvent = "note", kGraceNoteEvent = "grace", kRestEvent = "rest", kBarRestEvent = "rest", kTextEvent = "text",
  }
  local SPELLING = "[A-G][#bx]*%-?%d+"

  -- "13/2 (6.5)" gives 6.5 and "4" gives 4: the exact fraction, where there is one, beats the rounded decimal.
  local function number(s)
    local raw = s and s:match("^([%-%d%./]+)")
    if not raw then return nil end
    local a, b = raw:match("^(%-?%d+)/(%d+)$")
    if a then return tonumber(a) / tonumber(b) end
    return tonumber(raw)
  end

  function dump.event(text, instance)
    local s = text and text:match("^(k%a+ %(id:%d+%).*)$")
    if not s then return nil end
    local ev = { kind = KINDS[s:match("^(k%a+)")] or "other", raw = s, instance = instance }
    ev.id = tonumber(s:match("%(id:(%d+)%)"))
    ev.pos = number(s:match(" at (%S+)"))
    ev.duration = number(s:match(", duration (%S+)"))
    ev.grace = ev.kind == "grace"
    if ev.kind == "note" then
      ev.spelling = s:match("%s(" .. SPELLING .. ") %(ends")
    elseif ev.kind == "grace" then
      ev.spelling = s:match(",%s*(" .. SPELLING .. ")%s*$")
      ev.duration = nil
    elseif ev.kind == "text" then
      ev.text = s:match(" : (.*)$")
    end
    return ev
  end

  function dump.parse(text)
    local out, instance = { events = {} }, nil
    for line in (text or ""):gmatch("[^\r\n]+") do
      local start = line:match("^Start block id: (%d+)")
      if start then
        instance = tonumber(start)
      else
        local ev = dump.event(line:match(": (k%a+ %(id:%d+%).*)$"), instance)
        if ev then out.events[#out.events + 1] = ev end
      end
    end
    return out
  end

  function dump.notes(parsed)
    local notes = {}
    for _, ev in ipairs(parsed.events) do
      if (ev.kind == "note" or ev.kind == "grace") and ev.spelling then
        notes[#notes + 1] = { id = ev.id, spelling = ev.spelling, pos = ev.pos, duration = ev.duration,
          grace = ev.grace, instance = ev.instance }
      end
    end
    return notes
  end

  -- flow.instruments[i] owns flow.voiceStreams[i], and tostring(player) is the player's name.
  function dump.owners(score, flow)
    local nameOf = {}
    for _, player in ipairs(score.players) do
      for _, instrument in ipairs(player.instruments) do nameOf[instrument.id] = tostring(player) end
    end
    local owners = {}
    for i, stream in ipairs(flow.voiceStreams) do owners[stream.id] = nameOf[flow.instruments[i].id] end
    return owners
  end
end
-- end helper: dump

-- helper: commands
-- Builds a command string, "Name?key=value&key=value", for app:doCommand. Dorico reads a backslash in a value as an
-- escape, and a bare "&" or "," ends the value, so a value's own backslashes, ampersands and commas each get a
-- backslash in front; "=" and any other character pass as they are. A nil value is refused, since tostring would
-- send Dorico the word "nil". Only single ids have been tried in list parameters such as FlowIDArray; given several,
-- as "1,2", this would escape the commas between them.
--   commands.value(v) -> v escaped
--   commands.build(name, params) -> the command, params a list of {key, value} pairs
local commands = {}
do
  function commands.value(v)
    if v == nil then error("a command parameter has no value", 2) end
    return (tostring(v):gsub("\\", "\\\\"):gsub("&", "\\&"):gsub(",", "\\,"))
  end

  function commands.build(name, params)
    local parts = {}
    for i, kv in ipairs(params or {}) do parts[i] = kv[1] .. "=" .. commands.value(kv[2]) end
    if #parts == 0 then return name end
    return name .. "?" .. table.concat(parts, "&")
  end
end
-- end helper: commands

-- helper: export
-- File > Export > Text from a script: Dorico writes <name>.csv beside the <name>.txt it is given, without asking
-- anything. Fields can hold quoted commas, doubled quotes and newlines, so a row can run over several lines; the
-- reader below keeps track of quotes to find where each field and row ends. A column the export leaves out reads as "".
--   export.records(app, folder, name) -> the rows, as tables keyed by column name (the file is deleted afterwards)
--   export.parse(csv) -> the same, from CSV text
--   export.folder() -> the temporary folder, ending in a slash
-- Needs the commands helper above it.
local export = {}
do
  local COLUMNS = { "Path", "ID", "FlowNumber", "FlowName", "Instrument", "Page", "Bar", "Type", "Text", "Hidden" }

  local function rows(csv)
    if csv:sub(1, 3) == "\239\187\191" then csv = csv:sub(4) end -- a UTF-8 byte-order mark
    local out, row, field = {}, {}, {}
    local i, n, quoted, lineStart = 1, #csv, false, 1
    while i <= n do
      local c = csv:sub(i, i)
      if not quoted and (c == "\n" or c == "\r") and i == lineStart then
        -- a blank line is no row
        if c == "\r" and csv:sub(i + 1, i + 1) == "\n" then i = i + 1 end
        lineStart = i + 1
      elseif quoted then
        if c == '"' then
          if csv:sub(i + 1, i + 1) == '"' then field[#field + 1] = '"'; i = i + 1 else quoted = false end
        else
          field[#field + 1] = c
        end
      elseif c == '"' then
        quoted = true
      elseif c == "," then
        row[#row + 1] = table.concat(field)
        field = {}
      elseif c == "\n" or c == "\r" then
        if c == "\r" and csv:sub(i + 1, i + 1) == "\n" then i = i + 1 end
        row[#row + 1] = table.concat(field)
        out[#out + 1] = row
        row, field, lineStart = {}, {}, i + 1
      else
        field[#field + 1] = c
      end
      i = i + 1
    end
    if #field > 0 or #row > 0 then
      row[#row + 1] = table.concat(field)
      out[#out + 1] = row
    end
    return out
  end

  function export.parse(csv)
    local all = rows(csv)
    local header = all[1] or {}
    local records = {}
    for r = 2, #all do
      local rec = {}
      for _, name in ipairs(COLUMNS) do rec[name] = "" end
      for col, name in ipairs(header) do rec[name] = all[r][col] or "" end
      records[#records + 1] = rec
    end
    return records
  end

  function export.folder()
    local dir = os.getenv("TEMP") or os.getenv("TMPDIR") or os.getenv("TMP")
    if not dir then error("there is no TEMP or TMPDIR folder to export into") end
    if not dir:match("[/\\]$") then dir = dir .. "/" end
    return dir
  end

  function export.records(app, folder, name)
    local base = folder .. name
    os.remove(base .. ".csv")
    app:doCommand(commands.build("File.Export.Text", { { "File", base .. ".txt" }, { "Show", "false" } }))
    local f = io.open(base .. ".csv", "rb")
    if not f then error("File.Export.Text wrote no " .. base .. ".csv") end
    local csv = f:read("*a")
    f:close()
    os.remove(base .. ".csv")
    return export.parse(csv)
  end
end
-- end helper: export

-- helper: length
-- A position or duration in quarter notes, as the DoCore.RhythmicLength that createNote, createRest and createText
-- take. RhythmicLength(n) keeps only the whole part of n (0.5 gives 0), so a fraction goes in as
-- RhythmicLength(numerator, denominator): 1.5 quarter notes is RhythmicLength(3, 2).
local function length(quarters)
  for d = 1, 3840 do
    local n = quarters * d
    local whole = math.floor(n + 0.5)
    if math.abs(n - whole) < 1e-6 then return DoCore.RhythmicLength(whole, d) end
  end
  error("no fraction for " .. tostring(quarters) .. " quarter notes")
end
-- end helper: length

-- helper: midi
-- A spelling from the dump, such as "F#5", "Eb4" or "Bbb2", as a MIDI note number (middle C, "C4", is 60), or nil.
-- The octave goes with the letter, so "Cb4" is 59 and "B#3" is 60. "#" is a sharp, "x" a double sharp, "b" a flat.
local function midi(spelling)
  local letter, accidentals, octave = tostring(spelling):match("^([A-G])([#bx]*)(%-?%d+)$")
  if not letter then return nil end
  local n = ({ C = 0, D = 2, E = 4, F = 5, G = 7, A = 9, B = 11 })[letter] + (tonumber(octave) + 1) * 12
  for a in accidentals:gmatch(".") do
    n = n + ({ ["#"] = 1, x = 2, b = -1 })[a]
  end
  return n
end
-- end helper: midi

-- helper: bars
-- Where a bar starts, from marker texts: the text export gives each marker's bar, and the bar starts at the earliest
-- marked position in the same bar. Mark in two rounds:
--   bars.coarse(pos) -> whole quarter notes to mark first: pos rounded down, and up to 16 before it
--   bars.fine(start) -> points to mark next, every 1/24 of a quarter note between the whole quarter before start and
--                       start, since a bar can begin between whole quarters (after a pickup, or in 3/8)
--   bars.start(pos, barAt) -> the earliest marked position in pos's bar; barAt is {[position] = bar} for every
--                             marker placed, pos's own included
local bars = {}
do
  function bars.coarse(pos)
    local out = {}
    for q = math.floor(pos), math.max(0, math.floor(pos) - 16), -1 do out[#out + 1] = q end
    return out
  end

  function bars.fine(start)
    local out = {}
    for k = 1, 23 do
      local q = start - 1 + k / 24
      if q >= 0 then out[#out + 1] = q end
    end
    return out
  end

  function bars.start(pos, barAt)
    local bar, start = barAt[pos], pos
    for q, b in pairs(barAt) do
      if b == bar and q < start then start = q end
    end
    return start
  end
end
-- end helper: bars

local app, score = guard()
if not score then return end

local MARKER = "proofread "

-- Makes a marker text for each {stream, position, key}, exports, deletes the markers whatever happens, and gives back
-- {[key] = the marker's export row}.
local function marked(points)
  local made = {}
  for i, point in ipairs(points) do
    made[i] = { stream = point.stream,
      event = point.stream:createText(length(point.pos), length(1), MARKER .. i) }
  end
  local ok, records = pcall(export.records, app, export.folder(), "proofread")
  for _, m in ipairs(made) do m.stream:delete(m.event) end
  if not ok then error(records, 0) end
  local rows = {}
  for _, rec in ipairs(records) do
    if rec.Text:sub(1, #MARKER) == MARKER then
      local point = points[tonumber(rec.Text:sub(#MARKER + 1))]
      if point then rows[point.key] = rec end
    end
  end
  return rows
end

-- Every voice of every flow, with its notes (grace notes left out) and its player.
local voices = {}
for n, flow in ipairs(score.flows) do
  local owners = dump.owners(score, flow)
  for i, stream in ipairs(flow.voiceStreams) do
    local notes = {}
    for _, note in ipairs(dump.notes(dump.parse(stream:dump()))) do
      if not note.grace then
        note.midi = midi(note.spelling)
        notes[#notes + 1] = note
      end
    end
    voices[#voices + 1] = { flow = n, stream = stream, player = owners[stream.id] or "?",
      key = flow.instruments[i].id, notes = notes }
  end
end

-- Instrument names, one marker per voice.
local points = {}
for v, voice in ipairs(voices) do points[#points + 1] = { stream = voice.stream, pos = 0, key = v } end
local rows = marked(points)

local findings = {}
local function find(voice, pos, text)
  findings[#findings + 1] = { flow = voice.flow, stream = voice.stream, pos = pos, text = text }
end

for v, voice in ipairs(voices) do
  local name = rows[v] and rows[v].Instrument or ""
  local range
  for _, r in ipairs(RANGES) do
    if not range and name:lower():sub(1, #r[1]) == r[1]:lower() then range = r end
  end
  if range then
    for _, note in ipairs(voice.notes) do
      if note.midi < midi(range[2]) then
        find(voice, note.pos, string.format("%s plays %s, below its range (%s to %s)", voice.player, note.spelling,
          range[2], range[3]))
      elseif note.midi > midi(range[3]) then
        find(voice, note.pos, string.format("%s plays %s, above its range (%s to %s)", voice.player, note.spelling,
          range[2], range[3]))
      end
    end
  end
end

-- The top note a voice has sounding at a position, or nil.
local function top(voice, at)
  local best
  for _, note in ipairs(voice.notes) do
    if note.pos <= at and at < note.pos + note.duration and (not best or note.midi > best) then best = note.midi end
  end
  return best
end

-- Each pair of voices of one player in one flow, numbered within the player.
for a = 1, #voices do
  for b = a + 1, #voices do
    local va, vb = voices[a], voices[b]
    if va.flow == vb.flow and va.key == vb.key then
      local na, nb = 0, 0
      for v = 1, b do
        if voices[v].flow == va.flow and voices[v].key == va.key then
          if v <= a then na = na + 1 end
          nb = nb + 1
        end
      end
      local times, seen = {}, {}
      for _, note in ipairs(va.notes) do
        if not seen[note.pos] then seen[note.pos] = true; times[#times + 1] = note.pos end
      end
      for _, note in ipairs(vb.notes) do
        if not seen[note.pos] then seen[note.pos] = true; times[#times + 1] = note.pos end
      end
      table.sort(times)
      for i = 2, #times do
        local a1, b1, a2, b2 = top(va, times[i - 1]), top(vb, times[i - 1]), top(va, times[i]), top(vb, times[i])
        if a1 and b1 and a2 and b2 and a1 ~= a2 and b1 ~= b2 and (a2 - a1) * (b2 - b1) > 0 then
          local first, second = math.abs(a1 - b1) % 12, math.abs(a2 - b2) % 12
          local kind = (first == 7 and second == 7 and "fifths") or (first == 0 and second == 0 and "octaves")
          if kind then
            find(va, times[i], string.format("%s has parallel %s between voices %d and %d", va.player, kind, na, nb))
          end
        end
      end
    end
  end
end

table.sort(findings, function(x, y)
  if x.flow ~= y.flow then return x.flow < y.flow end
  if x.pos ~= y.pos then return x.pos < y.pos end
  return x.text < y.text
end)

-- Bars and beats, in two rounds of markers (see the bars helper). barAt[f] is {[position] = bar} for finding f.
local barAt = {}
local function markRound(round) -- round: a list of {finding number, position}
  local pts = {}
  for i, r in ipairs(round) do pts[i] = { stream = findings[r[1]].stream, pos = r[2], key = i } end
  local got = #pts > 0 and marked(pts) or {}
  for i, r in ipairs(round) do
    barAt[r[1]] = barAt[r[1]] or {}
    if got[i] then barAt[r[1]][r[2]] = got[i].Bar end
  end
end

local round = {}
for f, finding in ipairs(findings) do
  round[#round + 1] = { f, finding.pos }
  for _, q in ipairs(bars.coarse(finding.pos)) do round[#round + 1] = { f, q } end
end
markRound(round)
round = {}
for f, finding in ipairs(findings) do
  if barAt[f] and barAt[f][finding.pos] then
    for _, q in ipairs(bars.fine(bars.start(finding.pos, barAt[f]))) do round[#round + 1] = { f, q } end
  end
end
markRound(round)

for f, finding in ipairs(findings) do
  local at = barAt[f] or {}
  local bar = at[finding.pos] or "?"
  local start = at[finding.pos] and bars.start(finding.pos, at) or finding.pos
  print(string.format("%d bar %s beat %s: %s", finding.flow, bar, tostring(finding.pos - start + 1), finding.text))
end
print(#findings .. (#findings == 1 and " finding" or " findings"))
