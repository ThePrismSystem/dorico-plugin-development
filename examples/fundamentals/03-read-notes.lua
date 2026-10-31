-- Read every note in the project, through stream:dump(), which works on any music.
-- What it does: prints one line per note and grace note, with tabs between the columns: flow number, player, voice
-- (counted within the player), position and duration in quarter notes from the start of the flow, and the spelling
-- at sounding pitch. A grace note's duration reads "grace".
-- Changes: nothing (read-only).
-- Undo: nothing to undo.
-- Builds on: 02-walk-the-score.lua, for which player owns each voice. Open Script > Show Script Console to read what
-- it prints.
--
-- Reading stream.events raises an error on any voice that holds lyrics, slurs, hairpins, playing techniques or
-- another kind of item Lua has no class for, which is most real music. stream:dump() always works. It gives text,
-- one line per event, and the dump helper below turns that text into tables. Ties don't show: a tied note is one
-- note with the whole length. Implicit rests aren't events, so they don't show either.

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

local _, score = guard()
if not score then return end

local count = 0
for n, flow in ipairs(score.flows) do
  local owners = dump.owners(score, flow)
  local voices = {}
  for _, stream in ipairs(flow.voiceStreams) do
    local player = owners[stream.id] or "?"
    voices[player] = (voices[player] or 0) + 1
    for _, note in ipairs(dump.notes(dump.parse(stream:dump()))) do
      print(table.concat({ n, player, voices[player], note.pos, note.grace and "grace" or note.duration,
        note.spelling }, "\t"))
      count = count + 1
    end
  end
end
print(count .. " notes")
