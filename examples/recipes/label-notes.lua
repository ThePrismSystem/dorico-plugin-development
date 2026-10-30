-- Recipe: write a label above every note one player plays: its note name, or the trumpet valves that play it.
-- What it does: finds the first player whose name starts with PLAYER, and puts a staff text at each of its notes in
-- every flow: the valve numbers for the written note when LABELS is "valves", or the note's name when it's "names".
-- It prints how many labels it wrote. Change the three settings below for another player or instrument.
-- Changes: adds a staff text at each note of that player.
-- Undo: Edit > Undo takes all the labels back in one step.
-- Builds on: 03-read-notes.lua, 11-act-on-the-selection.lua (which labels notes the same way) and
-- 12-select-by-id.lua (for the midi helper). Open Script > Show Script Console to read what it prints.
--
-- The dump gives sounding pitch, and Lua can't read an instrument's transposition, so the script has to be told it:
-- TRANSPOSE is how many semitones the written note sits above the sounding one. A B-flat trumpet or clarinet is 2, an
-- instrument in C is 0, an E-flat alto saxophone 9. Names are printed at sounding pitch, as the dump spells them;
-- valves are looked up for the written pitch, since that's what the player reads.
--
-- A chord gets one label, with its notes' labels in a row. A note the valve table doesn't cover gets "?".

local PLAYER = "Trumpet"
local LABELS = "valves" -- or "names"
local TRANSPOSE = 2

-- Three-valve trumpet fingerings by written pitch, as a MIDI note number, from F#3 to C6: "0" is open, "12" is the
-- first and second valves together, and so on.
local VALVES = {
  [54] = "123", [55] = "13", [56] = "23", [57] = "12", [58] = "1", [59] = "2",
  [60] = "0", [61] = "123", [62] = "13", [63] = "23", [64] = "12", [65] = "1", [66] = "2",
  [67] = "0", [68] = "23", [69] = "12", [70] = "1", [71] = "2",
  [72] = "0", [73] = "12", [74] = "1", [75] = "2", [76] = "0", [77] = "1", [78] = "2",
  [79] = "0", [80] = "23", [81] = "12", [82] = "1", [83] = "2", [84] = "0",
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

local function label(spelling)
  if LABELS == "names" then return spelling end
  return VALVES[midi(spelling) + TRANSPOSE] or "?"
end

local written = 0
for _, flow in ipairs(score.flows) do
  for i, stream in ipairs(flow.voiceStreams) do
    if flow.instruments[i].id == key then
      -- One label per position, so a chord gets one.
      local at, order = {}, {}
      for _, note in ipairs(dump.notes(dump.parse(stream:dump()))) do
        if not at[note.pos] then
          at[note.pos] = {}
          order[#order + 1] = note.pos
        end
        table.insert(at[note.pos], label(note.spelling))
      end
      for _, pos in ipairs(order) do
        stream:createText(length(pos), length(1), table.concat(at[pos], " "))
        written = written + 1
      end
    end
  end
end
print(written .. " labels written")
