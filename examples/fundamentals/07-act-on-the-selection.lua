-- Find out which notes are selected, then act on them: here, by writing each note's name above it.
-- What it does: prints one line per selected note or grace note (flow number, player, position, spelling, with tabs
-- between), and puts a staff text naming the note at its position. With nothing selected it says so and stops.
-- Changes: adds a staff text for each selected note.
-- Undo: Edit > Undo can't take the texts back, since texts made through the stream object never enter the undo
-- history. Select them and press Delete, or use File > Revert. Don't press Edit > Redo straight afterwards either:
-- it would move the selected notes up a semitone (see below).
-- Builds on: 03-read-notes.lua. Select some notes, run the script, then open Script > Show Script Console to read
-- what it prints.
--
-- Lua has no way to ask what's selected, but the selected notes are the ones a command moves. So the script dumps
-- every voice, moves the selection up a semitone (NoteEdit.PitchUpChromatic), dumps again, and takes the move back
-- with Edit.Undo. The notes whose spelling changed are the selection. It finds notes and grace notes only, and misses
-- a note that can't go any higher.
--
-- That Edit.Undo is the only one a run can safely make. Inside a script it takes back that run's own commands and
-- nothing else, but once it has happened, any later command the run sends joins your last undo step, and a second
-- Edit.Undo would take back your own last edit. So after finding the selection, the script works through the object
-- model only (stream:createText here), which the undo history never sees.

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

local app, score = guard()
if not score then return end

-- Every note and grace note in every voice of every flow, by id.
local function snapshot()
  local notes = {}
  for n, flow in ipairs(app.currentScore.flows) do
    local owners = dump.owners(app.currentScore, flow)
    for i, stream in ipairs(flow.voiceStreams) do
      for _, note in ipairs(dump.notes(dump.parse(stream:dump()))) do
        note.flow, note.voice, note.player = n, i, owners[stream.id] or "?"
        notes[note.id] = note
      end
    end
  end
  return notes
end

local before = snapshot()
app:doCommand("NoteEdit.PitchUpChromatic")
local moved = snapshot()
app:doCommand("Edit.Undo")

local selected = {}
for id, note in pairs(before) do
  if moved[id] and moved[id].spelling ~= note.spelling then selected[#selected + 1] = note end
end
if #selected == 0 then
  print("Select one or more notes first, then run this script again.")
  return
end
table.sort(selected, function(a, b)
  if a.flow ~= b.flow then return a.flow < b.flow end
  if a.voice ~= b.voice then return a.voice < b.voice end
  if a.pos ~= b.pos then return a.pos < b.pos end
  return a.spelling < b.spelling
end)

-- One text for each position in a voice, naming every selected note there, so a chord gets one text.
local labels, order = {}, {}
for _, note in ipairs(selected) do
  print(table.concat({ note.flow, note.player, note.pos, note.spelling }, "\t"))
  local key = note.flow .. "/" .. note.voice .. "/" .. note.pos
  if not labels[key] then
    labels[key] = { note = note, names = {} }
    order[#order + 1] = key
  end
  table.insert(labels[key].names, note.spelling)
end
for _, key in ipairs(order) do
  local note = labels[key].note
  local stream = app.currentScore.flows[note.flow].voiceStreams[note.voice]
  stream:createText(length(note.pos), length(1), table.concat(labels[key].names, " "))
end
