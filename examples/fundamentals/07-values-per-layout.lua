-- Read a note's properties with the layout and block instance each one applies to, and the value each layout shows.
-- What it does: for every note with a property beyond its spelling, prints an "entry" line per stored value (player,
-- position, spelling, property, the value as stored, and where it applies), then a "value" line per property with
-- the value the full score shows and the value the player's part shows. A "-" means none.
-- Changes: nothing (read-only).
-- Undo: nothing to undo.
-- Builds on: 04-read-the-saved-copy.lua. Try it on a project where you've changed a note in a part, or with Edit
-- menu commands. Open Script > Show Script Console to read what it prints.
--
-- How a value was set decides where it applies. Set through Lua's property table or by EventEdit.ChangeProperty, it
-- has no context and holds in every layout. Edit.SetNoteheadSetOverride on a selection stores it for every layout
-- but only the note's own block instance. The Properties panel and the Edit menu's commands store it for the layout
-- on screen: set in a part, it shows only in that part, and set with the full score open, only in the full score.
-- score.value(s, e, property, layoutId) picks the value a layout shows, preferring one stored for that layout.
-- A value can also start partway through a note, such as the second half of a tied note.

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
local score = require("scorereader.score")
local values = require("scorereader.values")

local layoutNames, fullScore = {}, nil
for _, layout in ipairs(s.layouts) do
  layoutNames[layout.id] = layout.name
  if not fullScore and layout.type == "kFullScoreLayout" then fullScore = layout.id end
end

-- Where an entry applies, from its context.
local function where(x)
  local parts = { x.layout == -1 and "every layout" or ("layout " .. (layoutNames[x.layout] or x.layout)) }
  if x.instance ~= -1 then parts[#parts + 1] = "block instance " .. x.instance end
  local num, den = (x.offset or ""):match("^0:(%d+):(%d+):")
  if num and num ~= "0" then parts[#parts + 1] = num .. "/" .. den .. " into the note" end
  return table.concat(parts, ", ")
end

for _, flow in ipairs(s.flows) do
  for _, player in ipairs(s.players) do
    local part = score.partOf(s, player)
    for _, e in ipairs(score.eventsOf(s, flow, player)) do
      if e.kind == "note" or e.kind == "grace" then
        local pos, seen, order = values.positionText(e.position), {}, {}
        for _, x in ipairs(score.entries(s, e)) do
          if x.property ~= "kNoteSpelling" then
            print(table.concat({ "entry", player.name, pos, e.spelling, x.property, x.value, where(x) }, "\t"))
            if not seen[x.property] then seen[x.property], order[#order + 1] = true, x.property end
          end
        end
        for _, property in ipairs(order) do
          local inFull = score.value(s, e, property, fullScore)
          local inPart = part and score.value(s, e, property, part.id)
          print(table.concat({ "value", player.name, pos, e.spelling, property, tostring(inFull or "-"),
            tostring(inPart or "-") }, "\t"))
        end
      end
    end
  end
end
