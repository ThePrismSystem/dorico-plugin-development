-- Recipe: colour every note by its pitch class, one colour for each of the twelve, in rainbow order from C.
-- What it does: colours every note and grace note in every flow by command, C red through B magenta, and prints how
-- many notes each pitch class has, with its colour. Change COLOURS below to use your own.
-- Changes: the colour of every note, and the selection.
-- Undo: Edit > Undo takes all the colours back in one step.
-- Builds on: 03-read-notes.lua, 10-commands.lua and 12-select-by-id.lua. Open Script > Show Script Console to read
-- what it prints.
--
-- Classroom tuned percussion often colours each note this way, so that players can read by colour. The script reads
-- every note from the dump, works out its pitch class from its spelling (C# and Db get the same colour), and colours
-- it as 12-select-by-id.lua does: one note at a time, since each EventEdit.Select replaces the selection. A score with
-- many notes takes a while, and Dorico draws each change as it goes.
--
-- Colours set by command can't be read back from Lua, so a script can't later tell which colour a note has, only that
-- it has one.

-- Pitch class 0 is C, 1 is C# or Db, and so on to 11, B. Each colour is #aarrggbb: alpha, red, green, blue.
local COLOURS = {
  [0] = "#ffe41a1c", "#fff4511e", "#ffff7f00", "#ffffb300", "#ffd4b000", "#ff4daf4a",
  "#ff1b9e77", "#ff00a0b0", "#ff1f78b4", "#ff3f51b5", "#ff7b3294", "#ffc51b7d",
}
local NAMES = { [0] = "C", "C#/Db", "D", "D#/Eb", "E", "F", "F#/Gb", "G", "G#/Ab", "A", "A#/Bb", "B" }

-- helper: guard
-- The app and the open project, or the app and nil when no project is open. The read of app.currentScore goes
-- through pcall in case it raises an error then instead of giving nil, which no run here has checked. Such an error
-- is printed with the advice, in case it means something else.
local function guard()
  local app = DoApp.DoApp()
  local ok, score = pcall(function() return app.currentScore end)
  if ok and score then return app, score end
  local advice = "Open a project first, then run this script again."
  print(ok and advice or advice .. " Reading the open project gave an error: " .. tostring(score))
  return app, nil
end
-- end helper: guard

-- helper: dump
-- stream:dump() as tables. Each event line reads "<pos> (<pos>)[ dur: <d>]: <event>", where <event> is what
-- tostring(event) gives, such as "kNoteEvent (id:7932) at 0, duration 1  E5 (ends 1)". A "Start block id:" line
-- starts each block instance; the events after it belong to that instance (EventEdit.Select needs it).
--   dump.parse(text) -> {events = {{kind, id, pos, duration, spelling, grace, instance, raw}}}
--   dump.event(text, instance) -> one event from tostring(event), or nil
--   dump.notes(parsed) -> the notes and grace notes, {{id, spelling, pos, duration, grace, instance}}, and how
--     many it left out because their lines have no spelling it reads
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
    local notes, unread = {}, 0
    for _, ev in ipairs(parsed.events) do
      if (ev.kind == "note" or ev.kind == "grace") and ev.spelling then
        notes[#notes + 1] = { id = ev.id, spelling = ev.spelling, pos = ev.pos, duration = ev.duration,
          grace = ev.grace, instance = ev.instance }
      elseif ev.kind == "note" or ev.kind == "grace" then
        unread = unread + 1
      end
    end
    return notes, unread
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

local app, score = guard()
if not score then return end

-- Selecting only works outside note input, in Write mode.
app:doCommand("NoteInput.Exit")
app:doCommand(commands.build("Window.SwitchMode", { { "WindowMode", "kWriteMode" } }))

local counts = {}
for _, flow in ipairs(score.flows) do
  for _, stream in ipairs(flow.voiceStreams) do
    local parsed = dump.parse(stream:dump())
    for _, note in ipairs(dump.notes(parsed)) do
      local class = midi(note.spelling) % 12
      app:doCommand("Edit.SelectNone")
      app:doCommand(commands.build("EventEdit.Select", { { "FlowID", flow.id }, { "EventID", note.id },
        { "EventBlockID", blockIdOf(stream, note.id, parsed) } }))
      app:doCommand(commands.build("UI.InvokePropertyChangeValue", { { "Type", "kEventColour" },
        { "Value", COLOURS[class] } }))
      counts[class] = (counts[class] or 0) + 1
    end
  end
end
app:doCommand("Edit.SelectNone")

for class = 0, 11 do
  if counts[class] then print(string.format("%s: %d notes, %s", NAMES[class], counts[class], COLOURS[class])) end
end
