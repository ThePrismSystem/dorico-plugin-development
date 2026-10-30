-- Write music from a script: notes, a chord, a rest and a staff text, in a new flow of their own.
-- What it does: adds a flow at the end called "Written by a script", and in the first player's first voice writes a
-- C major scale in quarter notes, a C major chord, a quarter rest, two eighth notes and a staff text. It prints what
-- it wrote and for which player.
-- Changes: adds a flow, with music in it. Every player is in the new flow; the others have nothing to play there.
-- Undo: Edit > Undo takes the whole run back in one step: the new flow and the music in it. Everything a script run
-- changes goes into one undo step, made by command or through the object model (createNote, createRest,
-- createText) alike.
-- Builds on: 10-commands.lua. Open Script > Show Script Console to read what it prints.
--
-- Positions and durations are quarter notes from the start of the flow, and go in as DoCore.RhythmicLength values
-- (see the length helper). Pitches go in as DoCore.MIDIPitchWithSpelling.fromString(spelling), a sounding spelling
-- such as "F#4", which the note keeps exactly. On a transposing instrument, give the sounding pitch: a B-flat trumpet
-- shows "C4" written as D4. Two notes at one position in one voice make a chord.
--
-- fromString can crash Dorico when it's given something it can't read, or a pitch above MIDI note 127. The spellings
-- here are fixed and safe; check any that come from elsewhere (a file, a dialog) before passing them on.

local TITLE = "Written by a script"
local NOTES = { -- {spelling, position, duration}
  { "C4", 0, 1 }, { "D4", 1, 1 }, { "E4", 2, 1 }, { "F4", 3, 1 }, { "G4", 4, 1 }, { "A4", 5, 1 }, { "B4", 6, 1 },
  { "C5", 7, 1 },
  { "C4", 8, 2 }, { "E4", 8, 2 }, { "G4", 8, 2 },
  { "D5", 11, 0.5 }, { "E5", 11.5, 0.5 },
}
local REST = { 10, 1 } -- position, duration
local TEXT = { 0, "Written by a script" } -- position, text

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
if #score.players == 0 then
  print("Add a player first, then run this script again.")
  return
end

-- Project.Flow.New adds a flow at the end. It doesn't say which, so look for the id that wasn't there before.
local before = {}
for _, flow in ipairs(score.flows) do before[flow.id] = true end
app:doCommand("Project.Flow.New")
local flow, number
for n, f in ipairs(app.currentScore.flows) do
  if not before[f.id] then flow, number = f, n end
end
if not flow then error("Project.Flow.New added no flow") end
app:doCommand(commands.build("Project.Flow.Rename", { { "FlowID", flow.id }, { "Name", TITLE } }))

-- flow.voiceStreams[1] is the first voice of flow.instruments[1], the first player's first instrument.
local voice = flow.voiceStreams[1]
local player = "?"
for _, p in ipairs(app.currentScore.players) do
  for _, instrument in ipairs(p.instruments) do
    if instrument.id == flow.instruments[1].id then player = tostring(p) end
  end
end

for _, note in ipairs(NOTES) do
  voice:createNote(length(note[2]), length(note[3]), DoCore.MIDIPitchWithSpelling.fromString(note[1]))
end
voice:createRest(length(REST[1]), length(REST[2]))
voice:createText(length(TEXT[1]), length(1), TEXT[2])

print(string.format('flow %d, "%s": %d notes, 1 rest and 1 text for %s', number, TITLE, #NOTES, player))
