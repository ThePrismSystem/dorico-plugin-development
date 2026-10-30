-- Match the saved copy to Lua's own view of the score by event id.
-- What it does: dumps every stream of every flow, matches each dump to the saved copy, and prints a line per stream
-- ("stream", flow number, stream id, events matched, events left over), any reason an event didn't match, and a
-- total. Then it shows the first note from both sides: the dump's line for it, and what the copy says about it.
-- Changes: nothing (read-only).
-- Undo: nothing to undo.
-- Builds on: 03-read-notes.lua and 04-read-the-saved-copy.lua. Open Script > Show Script Console to read what it
-- prints.
--
-- Flow, stream and event ids in a saved copy are the ids Lua uses, so an event found in the copy can be looked up in
-- a dump, selected or changed by its id, with no matching by position or pitch. scorereader.dorico.match checks that
-- for one stream: an event only one side has, one at another position, a note spelled differently and a text with
-- other words each come back as a reason. s.events[id] is the copy's event with that id.

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
local dump = require("scorereader.dorico.dump")
local match = require("scorereader.dorico.match")
local values = require("scorereader.values")

local matched, leftOver, firstNote = 0, 0, nil
for n, flow in ipairs(project.flows) do
  for _, stream in ipairs(flow.allStreams) do
    local parsed = dump.parse(stream:dump())
    local m = match.stream(s, flow.id, stream.id, parsed)
    print(table.concat({ "stream", n, stream.id, m.count, #m.unmatched }, "\t"))
    for _, why in ipairs(m.unmatched) do print("unmatched\t" .. why) end
    matched, leftOver = matched + m.count, leftOver + #m.unmatched
    for _, ev in ipairs(parsed.events) do
      if not firstNote and ev.kind == "note" and m.byId[ev.id] then firstNote = ev end
    end
  end
end
print(table.concat({ "total", matched, leftOver }, "\t"))

if firstNote then
  local e = s.events[firstNote.id]
  print(table.concat({ "lua", firstNote.id, firstNote.raw }, "\t"))
  print(table.concat({ "file", e.id, e.kind, e.spelling, values.positionText(e.position), e.definition }, "\t"))
end
