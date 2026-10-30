-- Names and titles Lua can't read directly, from a saved copy: the project's title and composer, flow titles,
-- players, instruments and layouts.
-- What it does: prints "project: <title>", "composer: <composer>", a "flow <n>: <title>" line per flow, a
-- "player <n>: <name>" line per player, an "instrument <n>: ..." line per instrument with its id in Dorico's
-- instrument library and how it transposes, and a "layout <id>: <name> (<type>)" line per layout.
-- Changes: nothing (read-only).
-- Undo: nothing to undo.
-- Builds on: 04-read-the-saved-copy.lua. Open Script > Show Script Console to read what it prints.
--
-- Lua gives a flow no title, an instrument no name and the project no title. The saved copy has them all: the
-- project info in s.info, each flow's title, and each player with its instruments. A player's name has the
-- transposition Dorico adds ("Trumpet Zoë (B{@flat@})", with the flat as a token), and its instrument's name doesn't.
-- An instrument's transposition is how far its written notes sit above the sounding ones, in steps and semitones:
-- a B-flat trumpet's is 1 step and 2 semitones, a major second. The copy doesn't know where the project is saved;
-- the text export does (docs/guide.md, section 4).

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

local ok, s = pcall(savedcopy.read, app)
if not ok then
  print("The reader couldn't read this project: " .. tostring(s))
  return
end

local function orDash(text) return (text and text ~= "") and text or "-" end

print("project: " .. orDash(s.info.title))
print("composer: " .. orDash(s.info.composer))
for n, flow in ipairs(s.flows) do print("flow " .. n .. ": " .. orDash(flow.title)) end
local count = 0
for n, player in ipairs(s.players) do
  print("player " .. n .. ": " .. player.name)
  for _, instrument in ipairs(player.instruments) do
    count = count + 1
    local t = instrument.transposition
    local transposes = (t and (t.diatonic ~= 0 or t.chromatic ~= 0 or t.octaves ~= 0))
      and string.format("transposes %d steps, %d semitones, %d octaves", t.diatonic, t.chromatic, t.octaves)
      or "sounds as written"
    print(string.format("instrument %d: %s (%s), %s", count, instrument.name, instrument.entityID, transposes))
  end
end
local TYPES = { kFullScoreLayout = "full score", kPartLayout = "part" }
for _, layout in ipairs(s.layouts) do
  print(string.format("layout %d: %s (%s)", layout.id, layout.name, TYPES[layout.type] or layout.type))
end
