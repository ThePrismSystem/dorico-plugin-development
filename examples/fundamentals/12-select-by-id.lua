-- Select notes by id and run a command on each: here, colour every note above F5 red.
-- What it does: finds every note and grace note higher than F5 (sounding pitch) in every flow, selects each in turn
-- and colours it red by command, and prints one line per note it tried to colour (flow number, player, position,
-- spelling, with tabs between), then how many. doCommand reports nothing, so a note the commands missed still gets its
-- line: 13-set-a-property-by-id.lua shows how to read the colours back and check. Change ABOVE and COLOUR below to
-- pick other notes or another colour.
-- Changes: the colour of those notes, and the selection.
-- Undo: Edit > Undo takes all the colours back in one step.
-- Builds on: 03-read-notes.lua and 10-commands.lua. Open Script > Show Script Console to read what it prints.
--
-- EventEdit.Select?FlowID=&EventID=&EventBlockID= selects one event: its flow's id, its id from the dump, and the id
-- of the block that holds it, which the blockIdOf helper looks up. Each select replaces the selection, so the
-- script colours one note at a time.
--
-- The colour goes on through UI.InvokePropertyChangeValue, the command the Properties panel uses. Dorico stores it
-- for the layout on screen, so propertyTable:get can't read it back; 04-read-the-saved-copy.lua can. To set a value
-- for every layout without selecting anything, see 13-set-a-property-by-id.lua.

local ABOVE = "F5"
local COLOUR = "#ffff0000" -- alpha, red, green, blue

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

local limit, tried = midi(ABOVE), 0
for n, flow in ipairs(score.flows) do
  local owners = dump.owners(score, flow)
  for _, stream in ipairs(flow.voiceStreams) do
    local parsed = dump.parse(stream:dump())
    for _, note in ipairs(dump.notes(parsed)) do
      if midi(note.spelling) > limit then
        app:doCommand("Edit.SelectNone")
        app:doCommand(commands.build("EventEdit.Select", { { "FlowID", flow.id }, { "EventID", note.id },
          { "EventBlockID", blockIdOf(stream, note.id, parsed) } }))
        app:doCommand(commands.build("UI.InvokePropertyChangeValue", { { "Type", "kEventColour" },
          { "Value", COLOUR } }))
        print(table.concat({ n, owners[stream.id] or "?", note.pos, note.spelling }, "\t"))
        tried = tried + 1
      end
    end
  end
end
app:doCommand("Edit.SelectNone")
print("Tried to colour " .. tried .. " notes. Dorico doesn't report which took; 13-set-a-property-by-id.lua shows"
  .. " how to check.")
