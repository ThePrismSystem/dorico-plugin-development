-- Recipe: write a label above every note one player plays: its note name, or the trumpet valves that play it.
-- What it does: reads a saved copy, finds the first player whose name starts with PLAYER, and puts a staff text at
-- each of its notes in every flow: the valve numbers for the written note when LABELS is "valves", or the note's name
-- when it's "names". It prints how many labels it wrote. Change the two settings below for another player.
-- Changes: adds a staff text at each note of that player.
-- Undo: Edit > Undo takes all the labels back in one step.
-- Builds on: 04-read-the-saved-copy.lua, 05-names-and-titles.lua (instruments) and 11-act-on-the-selection.lua
-- (which labels notes the same way). Open Script > Show Script Console to read what it prints.
--
-- The saved copy spells notes at sounding pitch and gives each instrument's transposition: a B-flat trumpet's written
-- note is 2 semitones above the sounding one, and an instrument in C's is the same note. Valves are looked up for the
-- written pitch, since that's what the player reads, and names are printed at sounding pitch.
--
-- A chord gets one label, with its notes' labels in a row. A note the valve table doesn't cover gets "?".

local PLAYER = "Trumpet"
local LABELS = "valves" -- or "names"

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

-- helper: readCopy
-- Reads a saved copy of the open project with the reader library, or prints why it couldn't and gives nil. The
-- library is lib/ two folders up in this repository, or a lib folder beside the script once both are copied into
-- Script Plug-ins. Dorico keeps one Lua state, so the library's modules from an earlier run are cleared, and its
-- folders are moved to the front of the module path, where no other copy of the library can come before them.
local function readCopy(app)
  local here = debug.getinfo(1, "S").source:match("^@(.*[/\\])") or ""
  local paths = here .. "../../lib/?.lua;" .. here .. "lib/?.lua;"
  for name in pairs(package.loaded) do
    if name:match("^scorereader") then package.loaded[name] = nil end
  end
  local at = package.path:find(paths, 1, true)
  if at then package.path = package.path:sub(1, at - 1) .. package.path:sub(at + #paths) end
  package.path = paths .. package.path
  local ok, s = pcall(function() return require("scorereader.dorico.savedcopy").read(app) end)
  if ok then return s end
  print("The reader couldn't read this project: " .. tostring(s))
end
-- end helper: readCopy

local app, project = guard()
if not project then return end
local s = readCopy(app)
if not s then return end
local values = require("scorereader.values")

local player
for _, p in ipairs(s.players) do
  if p.name:sub(1, #PLAYER) == PLAYER then
    player = p
    break
  end
end
if not player then
  print(string.format("No player's name starts with %q. Change PLAYER at the top of the script.", PLAYER))
  return
end

local function label(e, transposition)
  if LABELS == "names" then return e.spelling end
  return VALVES[e.pitch + (transposition and transposition.chromatic or 0)] or "?"
end

-- Lua's voice streams by id, to write into.
local streams = {}
for _, flow in ipairs(project.flows) do
  for _, stream in ipairs(flow.voiceStreams) do streams[stream.id] = stream end
end

local written = 0
for _, flow in ipairs(s.flows) do
  for _, stream in ipairs(flow.streams) do
    if stream.type == "voice" and stream.playerId == player.id then
      local transposition = (s.instruments[stream.instrumentId] or {}).transposition
      -- One label per position, so a chord gets one.
      local at, order = {}, {}
      for _, e in ipairs(stream.events) do
        if e.kind == "note" or e.kind == "grace" then
          local pos = values.positionText(e.position)
          if not at[pos] then
            at[pos] = { position = e.position, labels = {} }
            order[#order + 1] = at[pos]
          end
          table.insert(at[pos].labels, label(e, transposition))
        end
      end
      table.sort(order, function(a, b) return values.toNumber(a.position) < values.toNumber(b.position) end)
      for _, chord in ipairs(order) do
        local p = chord.position
        streams[stream.id]:createText(DoCore.RhythmicLength(p.num, p.den), DoCore.RhythmicLength(1),
          table.concat(chord.labels, " "))
        written = written + 1
      end
    end
  end
end
print(written .. " labels written")
