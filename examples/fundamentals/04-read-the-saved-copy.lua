-- Read each note's notehead and colour from a saved copy of the project, which Lua can't read for itself.
-- What it does: saves a copy of the open project to the temp folder, reads it with the reader library and deletes
-- it. It prints the format the copy was saved in, then one line per note and grace note, with tabs between the
-- columns: flow number, player, position, spelling at sounding pitch, notehead set and colour, as the full score
-- shows them. A "-" means the note has none of its own.
-- Changes: nothing. app:save writes the copy without touching the project, its file, its unsaved mark or its undo
-- history.
-- Undo: nothing to undo.
-- Builds on: 03-read-notes.lua. It needs the lib folder: this repository's, or a copy of it beside the script in
-- Script Plug-ins. Open Script > Show Script Console to read what it prints.
--
-- Lua can't read a value set in Dorico's UI or by a command: Dorico keeps it for a layout or a block instance, and
-- propertyTable:get asks only for the value with neither. A saved project holds every value with its context, and
-- its event ids are the ones Lua uses. When Dorico can't save the copy, or the copy's format is one the reader has
-- never seen, savedcopy.read raises an error that says what went wrong, and the script prints it and stops.

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

-- helper: reader
-- Puts the reader library on the module path: lib/ two folders up in this repository, or a lib folder beside the
-- script once both are copied into Script Plug-ins. Dorico keeps one Lua state, so the library's modules from an
-- earlier run are cleared first.
local function reader()
  local here = debug.getinfo(1, "S").source:match("^@(.*[/\\])") or ""
  local paths = here .. "../../lib/?.lua;" .. here .. "lib/?.lua"
  for name in pairs(package.loaded) do
    if name:match("^scorereader") then package.loaded[name] = nil end
  end
  if not package.path:find(paths, 1, true) then package.path = paths .. ";" .. package.path end
end
-- end helper: reader

local app, project = guard()
if not project then return end
reader()
local savedcopy = require("scorereader.dorico.savedcopy")
local score = require("scorereader.score")
local values = require("scorereader.values")

local ok, s = pcall(savedcopy.read, app)
if not ok then
  print("The reader couldn't read this project: " .. tostring(s))
  return
end
print(table.concat({ "format", s.format.fileVersion, s.format.known and "known" or "unknown" }, "\t"))

-- A value set for one layout shows only there, so ask for the full score's. Layout ids are the ones the Remote API
-- and LayoutIDArray take.
local fullScore
for _, layout in ipairs(s.layouts) do
  if not fullScore and layout.type == "kFullScoreLayout" then fullScore = layout.id end
end

for n, flow in ipairs(s.flows) do
  for _, player in ipairs(s.players) do
    for _, e in ipairs(score.eventsOf(s, flow, player)) do
      if e.kind == "note" or e.kind == "grace" then
        print(table.concat({ n, player.name, values.toNumber(e.position), e.spelling,
          score.value(s, e, "kNoteheadSetOverride", fullScore) or "-",
          score.value(s, e, "kEventColour", fullScore) or "-" }, "\t"))
      end
    end
  end
end
