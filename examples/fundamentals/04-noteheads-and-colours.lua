-- Read each note's notehead and colour, which the dump doesn't show, even from music with lyrics or slurs.
-- What it does: prints one line per note and grace note, with tabs between the columns: flow number, player,
-- position, spelling at sounding pitch, notehead set and colour. A "-" means the note has none of its own. A colour
-- that reads "(unreadable)" was set in a way Lua can't read back (by Dorico's Properties panel or a command): the
-- note has a colour, but which one can't be known.
-- Changes: nothing that stays, but it uses the clipboard and the selection. A flow whose items Lua can't list is
-- copied (notes only) into a temporary flow, read there, and the temporary flows are taken away at the end. It also
-- leaves note input and switches to Write mode.
-- Undo: nothing to undo. The script takes its own temporary flows away with one Edit > Undo, which reaches only what
-- this run did. Don't press Edit > Redo straight afterwards, or the temporary flow comes back.
-- Builds on: 03-read-notes.lua. Run it with the full score open, so that every staff can be selected. Open
-- Script > Show Script Console to read what it prints.
--
-- Properties come from an event object's propertyTable, and event objects come from stream.events. That raises an
-- error on any stream holding an item with no Lua class: lyrics, slurs, hairpins, playing techniques. So the script
-- tries stream.events first, and for a flow where that fails it copies the music with Dorico's notes-and-chords
-- filter into a new flow, deletes the few lines the filter keeps, and reads the copy. Noteheads and colours come
-- with the copied notes. The paste merges unisons in two voices on one staff into one note.

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

local app, score = guard()
if not score then return end

-- Event kinds Lua has a class for. Any other kind in a stream makes stream.events raise an error.
local LISTABLE = {
  kNoteEvent = true, kGraceNoteEvent = true, kRestEvent = true, kBarRestEvent = true, kTextEvent = true,
  kTupletEvent = true, kClefEvent = true, kBreakEvent = true, kOttavaLineEvent = true, kBarDivisionEvent = true,
  kTonalityDivisionEvent = true, kDynamicGroupEvent = true,
}

local ctx = DoCore.PropertyContext()
local lines = {}

-- Flow objects go stale once commands have changed the project, so look a flow up again after each step.
local function flowById(id)
  for _, f in ipairs(app.currentScore.flows) do
    if f.id == id then return f end
  end
end

-- Each voice stream's event list, or nil when any of them can't be listed.
local function eventLists(flow)
  local lists = {}
  for i, stream in ipairs(flow.voiceStreams) do
    local ok, list = pcall(function() return stream.events end)
    if not ok then return nil end
    lists[i] = list
  end
  return lists
end

-- A property's value, "-" when the note doesn't have it, and "(unreadable)" when it has it but Lua reads an empty
-- value. getPropertyNames lists only the properties a note has.
local function property(event, has, name)
  if not has[name] then return "-" end
  local value = tostring(event.propertyTable:get(name, ctx))
  return value ~= "" and value or "(unreadable)"
end

-- Each voice's notes in order of position, then spelling. A pasted copy lists a chord's notes in a different order
-- each time, and sorting keeps two runs alike.
local function readLists(number, flow, lists, skipId)
  local owners = dump.owners(app.currentScore, flow)
  for i, stream in ipairs(flow.voiceStreams) do
    local notes = {}
    for _, event in ipairs(lists[i]) do
      local ev = dump.event(tostring(event))
      if ev and (ev.kind == "note" or ev.kind == "grace") and ev.id ~= skipId then
        local has = {}
        for _, name in ipairs(event.propertyTable:getPropertyNames()) do has[tostring(name)] = true end
        ev.line = table.concat({ number, owners[stream.id] or "?", ev.pos, ev.spelling,
          property(event, has, "kNoteheadSetOverride"), property(event, has, "kEventColour") }, "\t")
        notes[#notes + 1] = ev
      end
    end
    table.sort(notes, function(a, b)
      if a.pos ~= b.pos then return a.pos < b.pos end
      return a.spelling < b.spelling
    end)
    for _, ev in ipairs(notes) do lines[#lines + 1] = ev.line end
  end
end

local function select(flowId, stream, eventId)
  app:doCommand("Edit.SelectNone")
  app:doCommand(commands.build("EventEdit.Select", { { "FlowID", flowId }, { "EventID", eventId },
    { "EventBlockID", blockIdOf(stream, eventId, dump.parse(stream:dump())) } }))
end

-- Copies a flow's notes into a new flow that has only that flow's players, and reads the copy.
local function readCopy(number, flowId)
  local before = {}
  for _, f in ipairs(app.currentScore.flows) do before[f.id] = true end
  app:doCommand("Project.Flow.New")
  local copyId
  for _, f in ipairs(app.currentScore.flows) do
    if not before[f.id] then copyId = f.id end
  end
  if not copyId then error("Project.Flow.New added no flow") end

  -- A new flow holds every player. Players have no ==, so they're matched by their first instrument's id.
  local inFlow = {}
  for _, player in ipairs(flowById(flowId).players) do inFlow[player.instruments[1].id] = true end
  for _, player in ipairs(flowById(copyId).players) do
    if not inFlow[player.instruments[1].id] then flowById(copyId):removePlayer(player) end
  end

  -- The whole flow, every staff: select its first note or rest, stretch the selection to both ends of the flow and
  -- down to the last staff, keep only notes and chords, and copy.
  local flow = flowById(flowId)
  local first, firstStream
  for _, stream in ipairs(flow.voiceStreams) do
    for _, ev in ipairs(dump.parse(stream:dump()).events) do
      if not first and (ev.kind == "note" or ev.kind == "grace" or ev.kind == "rest") then
        first, firstStream = ev.id, stream
      end
    end
    if first then break end
  end
  if not first then return end
  select(flowId, firstStream, first)
  app:doCommand("Edit.SelectToStartOfFlow")
  app:doCommand("Edit.SelectAtEndOfFlow")
  for _ = 2, #flow.staveStreams do app:doCommand("EventEdit.NavigateDownExtend") end
  app:doCommand("Filter.NotesAndChords")
  app:doCommand("Edit.Copy")

  -- Paste onto a temporary note at the start of the copy's top staff. The note goes with the rest of the run's
  -- edits at the script's one Edit.Undo.
  local top = flowById(copyId).voiceStreams[1]
  local temp = top:createNote(DoCore.RhythmicLength(0), DoCore.RhythmicLength(1),
    DoCore.MIDIPitchWithSpelling.fromString("C5"))
  local tempId = temp.id
  select(copyId, top, tempId)
  app:doCommand("Edit.Paste")

  -- The filter keeps lines attached to the notes, such as slurs, and those still stop stream.events. Delete each
  -- unlistable item from the copy, one at a time, by selecting it by id.
  for _, stream in ipairs(flowById(copyId).voiceStreams) do
    if not pcall(function() return stream.events end) then
      for _, ev in ipairs(dump.parse(stream:dump()).events) do
        if not LISTABLE[ev.raw:match("^(k%a+)")] then
          select(copyId, stream, ev.id)
          app:doCommand("Edit.Delete")
        end
      end
    end
  end
  app:doCommand("Edit.SelectNone")

  local copy = flowById(copyId)
  local lists = eventLists(copy)
  if not lists then error("the copy of flow " .. number .. " still can't be listed") end
  readLists(number, copy, lists, tempId)
end

app:doCommand("NoteInput.Exit")
app:doCommand(commands.build("Window.SwitchMode", { { "WindowMode", "kWriteMode" } }))

local flowIds = {}
for n, flow in ipairs(score.flows) do flowIds[n] = flow.id end

-- Exactly one Edit.Undo, and only when something was copied. Inside a script it takes back that run's own command
-- edits; a second one would take back the user's last edit as well.
local copied = false
local ok, err = pcall(function()
  for n, id in ipairs(flowIds) do
    local lists = eventLists(flowById(id))
    if lists then
      readLists(n, flowById(id), lists)
    else
      copied = true
      readCopy(n, id)
    end
  end
end)
if copied then app:doCommand("Edit.Undo") end
if not ok then error(err, 0) end

for _, line in ipairs(lines) do print(line) end
