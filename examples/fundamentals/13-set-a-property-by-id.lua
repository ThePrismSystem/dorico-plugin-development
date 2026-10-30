-- Set a property on notes by their ids, with nothing selected: here, colour every note above F5 blue.
-- What it does: reads a saved copy, finds every note and grace note higher than F5 (sounding pitch) and sets its
-- colour by event id. Then it reads a second copy to see that each took, and prints one line per note (flow number,
-- player, position, spelling, and "coloured" or "not coloured", with tabs between) and a "total" line: how many
-- took, of how many it set.
-- Change COLOUR below to use another colour.
-- Changes: the colour of those notes, in every layout.
-- Undo: Edit > Undo takes all the colours back in one step.
-- Builds on: 04-read-the-saved-copy.lua and 12-select-by-id.lua. Open Script > Show Script Console to read what it
-- prints.
--
-- EventEdit.ChangeProperty?FlowID=&EventID=&EventBlockID=&Type=&Value= sets one property on one event, found by its
-- ids, without selecting it: scorereader.dorico.edit.setProperty builds the command from an event the reader found. The
-- value has no context, so every layout shows it unless that layout has a value of its own: 12's colour, set through
-- the Properties panel's command, is stored for the layout on screen and wins there. Leaving Value out takes the
-- property off again (edit.removeProperty). The same call puts an accidental in brackets: kNoteAccidentalVisibility_v3
-- with kRoundBrackets or kSquareBrackets.

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

local ABOVE = 77 -- F5, as a MIDI note number
local COLOUR = "#ff1f78b4" -- alpha, red, green, blue

local app, project = guard()
if not project then return end
local s = readCopy(app)
if not s then return end
local edit = require("scorereader.dorico.edit")
local score = require("scorereader.score")
local values = require("scorereader.values")

local function line(...) print(table.concat({ ... }, "\t")) end

local set = {}
for n, flow in ipairs(s.flows) do
  for _, player in ipairs(s.players) do
    for _, e in ipairs(score.eventsOf(s, flow, player)) do
      if (e.kind == "note" or e.kind == "grace") and e.pitch > ABOVE then
        edit.setProperty(app, e, "kEventColour", COLOUR)
        set[#set + 1] = { flow = n, player = player.name, e = e }
      end
    end
  end
end

-- A command reports nothing, so read a second copy and look on each note for the colour stored for every layout and
-- block instance, as EventEdit.ChangeProperty stores it.
local after = readCopy(app)
if not after then return end
local coloured = 0
for _, x in ipairs(set) do
  local stored, e = false, after.events[x.e.id]
  for _, entry in ipairs(e and score.entries(after, e) or {}) do
    if entry.property == "kEventColour" and entry.layout == -1 and entry.instance == -1 then
      stored = values.typed(entry.value).value == COLOUR
    end
  end
  if stored then coloured = coloured + 1 end
  line(x.flow, x.player, values.toNumber(x.e.position), x.e.spelling, stored and "coloured" or "not coloured")
end
line("total", coloured, #set)
