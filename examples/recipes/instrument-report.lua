-- Recipe: an instrument list, flow by flow, with how much each player plays and how many play at once.
-- What it does: prints each flow's number, title and player count, then a line per player in it, "<player> |
-- <instruments> | <n> notes", then the most players that have a note sounding at the same moment, which is the
-- number of players the flow needs if nobody doubles.
-- Changes: nothing that stays. It makes marker texts to read instrument names and flow titles from the text export,
-- and deletes them again.
-- Undo: nothing to undo. The markers still make an undo step, so Edit > Undo straight after this script changes
-- nothing you can see; a second press reaches your own last edit.
-- Builds on: 02-walk-the-score.lua, 03-read-notes.lua and 05-names-from-the-text-export.lua. Open Script > Show
-- Script Console to read what it prints.
--
-- A player's instruments are named as the export names them: one marker in a voice of each instrument, and the
-- Instrument column of its row. An instrument with no voice in any flow can't be named this way, and shows as "?".
-- Notes count grace notes too. "At once" means a note's sounding span covers the moment another starts, so a held
-- note counts until it ends.

-- helper: guard
-- The app and the open project, or the app and nil when no project is open. With only the Hub showing, reading
-- app.currentScore can raise an error instead of giving nil, so the read goes through pcall.
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
-- send Dorico the word "nil".
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
-- anything. Fields can hold quoted commas, doubled quotes and newlines, so the CSV is read with a quote-aware reader,
-- never split line by line. A column the export leaves out reads as "".
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

local app, score = guard()
if not score then return end

local MARKER = "instrument-report "

-- One marker at the start of the first voice of each instrument, then one export for names and titles.
local markers, marked = {}, {}
for _, flow in ipairs(score.flows) do
  for i, stream in ipairs(flow.voiceStreams) do
    local id = flow.instruments[i].id
    if not marked[id] then
      marked[id] = true
      markers[#markers + 1] = { stream = stream,
        event = stream:createText(DoCore.RhythmicLength(0), DoCore.RhythmicLength(1), MARKER .. id) }
    end
  end
end
local ok, records = pcall(export.records, app, export.folder(), "instrument-report")
for _, m in ipairs(markers) do m.stream:delete(m.event) end
if not ok then error(records, 0) end

local instrumentNames, flowTitles = {}, {}
for _, rec in ipairs(records) do
  if rec.Text:sub(1, #MARKER) == MARKER then
    instrumentNames[tonumber(rec.Text:sub(#MARKER + 1))] = rec.Instrument
  end
  if rec.Type == "Flow Info (Title)" and tonumber(rec.FlowNumber) then
    flowTitles[tonumber(rec.FlowNumber)] = rec.Text
  end
end

for n, flow in ipairs(score.flows) do
  -- Notes by player (keyed by first instrument id), and each player's sounding spans.
  local count, spans, owner = {}, {}, {}
  for _, player in ipairs(score.players) do
    for _, instrument in ipairs(player.instruments) do owner[instrument.id] = player.instruments[1].id end
  end
  for i, stream in ipairs(flow.voiceStreams) do
    local key = owner[flow.instruments[i].id]
    for _, note in ipairs(dump.notes(dump.parse(stream:dump()))) do
      count[key] = (count[key] or 0) + 1
      if not note.grace then
        spans[key] = spans[key] or {}
        table.insert(spans[key], { note.pos, note.pos + note.duration })
      end
    end
  end

  print(string.format('flow %d "%s": %d players', n, flowTitles[n] or "?", #flow.players))
  for _, player in ipairs(flow.players) do
    local names = {}
    for _, instrument in ipairs(player.instruments) do names[#names + 1] = instrumentNames[instrument.id] or "?" end
    print(string.format("  %s | %s | %d notes", tostring(player), table.concat(names, ", "),
      count[player.instruments[1].id] or 0))
  end

  -- The most players sounding at once can only change where a note starts, so count at each start.
  local most = 0
  for _, list in pairs(spans) do
    for _, span in ipairs(list) do
      local at, playing = span[1], 0
      for _, other in pairs(spans) do
        for _, s in ipairs(other) do
          if s[1] <= at and at < s[2] then
            playing = playing + 1
            break
          end
        end
      end
      if playing > most then most = playing end
    end
  end
  print("  most players playing at once: " .. most)
end
