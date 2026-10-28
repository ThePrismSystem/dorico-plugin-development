-- Recipe: name the chords one player plays, and write them in as chord symbols.
-- What it does: finds the first player whose name starts with PLAYER and, at every point where one of its notes
-- starts, names the chord all its sounding notes make (both hands of a piano, any voice). Where the chord changes,
-- it adds a chord symbol there, through the chord symbol popover's own commands, and prints "flow <n> at <position>:
-- <chord>". Positions are quarter notes from the start of the flow.
-- Changes: adds chord symbols where the flow has none, and changes the selection. A chord symbol already in place is
-- left as it is, since entering another there would replace it.
-- Undo: Edit > Undo takes the chord symbols back one at a time, three presses each: the chord symbol popover's
-- commands make undo steps of their own, unlike the rest of a run (the sample's four took eleven presses). To
-- remove them all at once, select the passage, filter the selection to chord symbols, and press Delete.
-- Builds on: 03-read-notes.lua, 06-commands.lua and 08-select-by-id.lua. Open Script > Show Script Console to read
-- what it prints.
--
-- It names a chord wherever three or more pitch classes sound, from a short list of types (major, minor, diminished,
-- augmented, sus4, and the common sevenths). Inversions are named by their root. Passing notes count too, so a busy
-- texture can give odd names; a real chord-finder would weigh beats and durations, which this doesn't. Lua can't read
-- time signatures, so it can't work bar by bar.
--
-- A chord symbol goes in as the popover would put it: select a note at the right place, then
--   NoteInput.StartChordSymbolInput
--   NoteInput.AcceptCurrentChordSymbolTextInput?Definition=<chord>&ChordSymbolEntryAdvanceType=kEndInput
-- The second command alone makes nothing.

local PLAYER = "Piano"

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

-- helper: blockIdOf
-- The block id EventEdit.Select needs for an event. The dump's "Start block id" names a block instance, despite
-- its name, and the instance's block carries the id to select by. A select with any other number selects nothing
-- and raises no error. parsed is dump.parse(stream:dump()).
local function blockIdOf(stream, eventId, parsed)
  local instance
  for _, ev in ipairs(parsed.events) do
    if ev.id == eventId then instance = ev.instance end
  end
  for _, bi in ipairs(stream.blockInstances) do
    if bi.id == instance then return bi.block.id end
  end
  error("no block holds event " .. tostring(eventId))
end
-- end helper: blockIdOf

-- helper: chords
-- Names the chord a set of notes makes, as the chord symbol popover takes it ("C", "Am", "G7", "Bbmaj7"), or nil when
-- fewer than three pitch classes sound or no chord type fits them exactly. Notes are spellings from the dump. Their
-- octaves don't matter, except that the lowest note is tried as the root first, so an inversion is named by its root
-- and a chord that fits several roots (an augmented or diminished seventh chord) takes the bass note's.
--   chords.name(spellings) -> name or nil
local chords = {}
do
  local LETTERS = { C = 0, D = 2, E = 4, F = 5, G = 7, A = 9, B = 11 }
  local ACCIDENTALS = { ["#"] = 1, x = 2, b = -1 }
  -- Each chord type: the suffix the popover reads, and its pitch classes counted in semitones above the root.
  local TYPES = {
    { "", { 0, 4, 7 } }, { "m", { 0, 3, 7 } }, { "dim", { 0, 3, 6 } }, { "aug", { 0, 4, 8 } },
    { "sus4", { 0, 5, 7 } }, { "7", { 0, 4, 7, 10 } }, { "maj7", { 0, 4, 7, 11 } }, { "m7", { 0, 3, 7, 10 } },
    { "m7b5", { 0, 3, 6, 10 } }, { "dim7", { 0, 3, 6, 9 } },
  }

  local function parse(spelling)
    local letter, accidentals, octave = tostring(spelling):match("^([A-G])([#bx]*)(%-?%d+)$")
    if not letter then return nil end
    local n = LETTERS[letter]
    for a in accidentals:gmatch(".") do n = n + ACCIDENTALS[a] end
    return { class = n % 12, midi = n + (tonumber(octave) + 1) * 12, name = letter .. accidentals }
  end

  function chords.name(spellings)
    local notes, nameOf, count = {}, {}, 0
    for _, s in ipairs(spellings) do
      local n = parse(s)
      if n then
        notes[#notes + 1] = n
        if not nameOf[n.class] then
          nameOf[n.class] = n.name
          count = count + 1
        end
      end
    end
    if count < 3 then return nil end
    table.sort(notes, function(a, b) return a.midi < b.midi end)
    for _, root in ipairs(notes) do
      for _, kind in ipairs(TYPES) do
        local suffix, steps = kind[1], kind[2]
        if #steps == count then
          local fits = true
          for _, step in ipairs(steps) do
            if not nameOf[(root.class + step) % 12] then fits = false end
          end
          if fits then return nameOf[root.class] .. suffix end
        end
      end
    end
    return nil
  end
end
-- end helper: chords

local app, score = guard()
if not score then return end

local key
for _, player in ipairs(score.players) do
  if not key and tostring(player):sub(1, #PLAYER) == PLAYER then key = player.instruments[1].id end
end
if not key then
  print(string.format("No player's name starts with %q. Change PLAYER at the top of the script.", PLAYER))
  return
end

-- Selecting only works outside note input, in Write mode.
app:doCommand("NoteInput.Exit")
app:doCommand(commands.build("Window.SwitchMode", { { "WindowMode", "kWriteMode" } }))

local count = 0
for n, flow in ipairs(score.flows) do
  -- Every note the player has in this flow, from all its voices, with what selecting it needs.
  local notes, onsets, seen = {}, {}, {}
  for i, stream in ipairs(flow.voiceStreams) do
    if flow.instruments[i].id == key then
      local parsed = dump.parse(stream:dump())
      for _, note in ipairs(dump.notes(parsed)) do
        if not note.grace then
          note.stream, note.parsed = stream, parsed
          notes[#notes + 1] = note
          if not seen[note.pos] then
            seen[note.pos] = true
            onsets[#onsets + 1] = note.pos
          end
        end
      end
    end
  end
  table.sort(onsets)

  -- Chord symbols the flow already has, by position, from its timebase stream (type 0). Entering one where one
  -- exists replaces it, so those places are left as they are.
  local existing = {}
  for _, stream in ipairs(flow.allStreams) do
    if stream.type == 0 then
      for _, ev in ipairs(dump.parse(stream:dump()).events) do
        if ev.raw:match("^kChordSymbolEvent") then existing[ev.pos] = true end
      end
    end
  end

  local last
  for _, at in ipairs(onsets) do
    local sounding, starter = {}, nil
    for _, note in ipairs(notes) do
      if note.pos <= at and at < note.pos + note.duration then sounding[#sounding + 1] = note.spelling end
      if note.pos == at then starter = starter or note end
    end
    local name = chords.name(sounding)
    if name and name ~= last then
      if existing[at] then
        print(string.format("flow %d at %s: %s (a chord symbol is already there, left as it is)", n, tostring(at),
          name))
      else
        app:doCommand("Edit.SelectNone")
        app:doCommand(commands.build("EventEdit.Select", { { "FlowID", flow.id }, { "EventID", starter.id },
          { "EventBlockID", blockIdOf(starter.stream, starter.id, starter.parsed) } }))
        app:doCommand("NoteInput.StartChordSymbolInput")
        app:doCommand(commands.build("NoteInput.AcceptCurrentChordSymbolTextInput", { { "Definition", name },
          { "ChordSymbolEntryAdvanceType", "kEndInput" } }))
        print(string.format("flow %d at %s: %s", n, tostring(at), name))
      end
      count = count + 1
    end
    last = name or last
  end
end
app:doCommand("Edit.SelectNone")
if count == 0 then print("No chords found.") end
