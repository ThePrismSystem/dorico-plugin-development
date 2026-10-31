-- Read each note's notehead and colour from a saved copy of the project, which Lua can't read for itself.
-- What it does: saves a copy of the open project to the temp folder, reads it with the reader library and deletes
-- it. It prints the format the copy was saved in, then one line per note and grace note, with tabs between the
-- columns: flow number, player, position, spelling at sounding pitch, notehead set and colour, as the full score
-- shows them. A "-" means the note has none of its own. A project whose full score layout was deleted gets a
-- line saying so instead.
-- Changes: nothing. app:save writes the copy without touching the project, its file, its unsaved mark or its undo
-- history.
-- Undo: nothing to undo.
-- Builds on: 03-read-notes.lua. It needs the lib folder: this repository's, or a copy of it beside the script in
-- Script Plug-ins. Open Script > Show Script Console to read what it prints.
--
-- Lua can't read a value set in Dorico's UI or by a command: Dorico keeps it for a layout or a block instance, and
-- propertyTable:get asks only for the value with neither. A saved project holds every value with its context, and
-- its event ids are the ones Lua uses. When Dorico can't save the copy, or the copy holds a structure the reader
-- doesn't know, savedcopy.read raises an error that says what went wrong, and the script prints it and stops. A
-- fileVersion the reader hasn't seen is still read when its structure fits a known one, and the format line then
-- says "unknown".

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

-- helper: readCopy
-- Reads a saved copy of the open project with the reader library, or prints why it couldn't and gives nil. The
-- library is lib/ two folders up in this repository, or a lib folder beside the script once both are copied into
-- Script Plug-ins. Dorico keeps one Lua state, so the library's modules from an earlier run are cleared, and its
-- folders are moved to the front of the module path, where no other copy of the library can come before them. The
-- library loads outside the pcall, so a missing or broken library isn't reported as a project it couldn't read.
local function readCopy(app)
  local here = debug.getinfo(1, "S").source:match("^@(.*[/\\])") or ""
  local paths = here .. "../../lib/?.lua;" .. here .. "lib/?.lua;"
  for name in pairs(package.loaded) do
    if name:match("^scorereader") then package.loaded[name] = nil end
  end
  local at = package.path:find(paths, 1, true)
  if at then package.path = package.path:sub(1, at - 1) .. package.path:sub(at + #paths) end
  package.path = paths .. package.path
  if package.searchpath("scorereader.dorico.savedcopy", package.path) then
    local savedcopy = require("scorereader.dorico.savedcopy")
    local ok, s = pcall(savedcopy.read, app)
    if ok then return s end
    print("The reader couldn't read this project: " .. tostring(s))
  else
    print("Couldn't find the reader library: copy the lib folder beside this script, then run it again.")
  end
end
-- end helper: readCopy

local app, project = guard()
if not project then return end
local s = readCopy(app)
if not s then return end
local score = require("scorereader.score")
local values = require("scorereader.values")

local function line(...) print(table.concat({ ... }, "\t")) end

line("format", s.format.fileVersion, s.format.known and "known" or "unknown")

-- A value set for one layout shows only there, so ask for the full score's. Layout ids are the ones the Remote API
-- and LayoutIDArray take.
local fullScore = score.fullScoreOf(s)
if not fullScore then
  print("This project has no full score layout, so there are no full score values to print.")
  return
end

for n, flow in ipairs(s.flows) do
  for _, player in ipairs(s.players) do
    for _, e in ipairs(score.eventsOf(s, flow, player)) do
      if e.kind == "note" or e.kind == "grace" then
        line(n, player.name, values.toNumber(e.position), e.spelling,
          score.value(s, e, "kNoteheadSetOverride", fullScore.id) or "-",
          score.value(s, e, "kEventColour", fullScore.id) or "-")
      end
    end
  end
end
