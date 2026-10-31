-- Recipe: an instrument list, flow by flow, with how much each player plays and how many play at once.
-- What it does: prints each flow's number, title and player count, then a line per player in it, "<player> |
-- <instruments> | <n> notes", then the most players that have a note sounding at the same moment, which is the
-- number of players the flow needs if nobody doubles.
-- Changes: nothing (read-only).
-- Undo: nothing to undo.
-- Builds on: 02-walk-the-score.lua, 04-read-the-saved-copy.lua and 05-names-and-titles.lua. Open Script > Show Script
-- Console to read what it prints.
--
-- Flow titles, player names and instrument names all come from a saved copy. Notes count grace notes too. "At once"
-- means a note's sounding span covers the moment another starts, so a held note counts until it ends.

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

-- helper: mostAtOnce
-- The most players with a note sounding at one moment. spans: {[player] = {{start, end}}}, in quarter notes; a note
-- sounds from its start up to its end, so one that ends where another starts doesn't overlap it. It sorts every
-- start and end once and goes through them in order, counting the players sounding, so a score twice as long takes
-- about twice as long.
local function mostAtOnce(spans)
  local marks = {}
  for player, list in pairs(spans) do
    for _, span in ipairs(list) do
      marks[#marks + 1] = { pos = span[1], step = 1, player = player }
      marks[#marks + 1] = { pos = span[2], step = -1, player = player }
    end
  end
  -- At the same moment, ends go first.
  table.sort(marks, function(a, b)
    if a.pos ~= b.pos then return a.pos < b.pos end
    return a.step < b.step
  end)
  local notes, sounding, most = {}, 0, 0
  for _, m in ipairs(marks) do
    local before = notes[m.player] or 0
    notes[m.player] = before + m.step
    if before == 0 then
      sounding = sounding + 1
      most = math.max(most, sounding)
    elseif notes[m.player] == 0 then
      sounding = sounding - 1
    end
  end
  return most
end
-- end helper: mostAtOnce

local app, project = guard()
if not project then return end
local s = readCopy(app)
if not s then return end
local score = require("scorereader.score")
local values = require("scorereader.values")

for n, flow in ipairs(s.flows) do
  -- A player is in a flow when the flow has the player's own stream.
  local inFlow, players = {}, {}
  for _, stream in ipairs(flow.streams) do
    if stream.type == "player" then inFlow[stream.playerId] = true end
  end
  for _, player in ipairs(s.players) do
    if inFlow[player.id] then players[#players + 1] = player end
  end

  print(string.format('flow %d "%s": %d players', n, flow.title, #players))
  local spans = {}
  for _, player in ipairs(players) do
    local count = 0
    for _, e in ipairs(score.eventsOf(s, flow, player)) do
      if e.kind == "note" or e.kind == "grace" then count = count + 1 end
      if e.kind == "note" then
        local pos = values.toNumber(e.position)
        spans[player.id] = spans[player.id] or {}
        table.insert(spans[player.id], { pos, pos + values.toNumber(e.duration) })
      end
    end
    local names = {}
    for _, instrument in ipairs(player.instruments) do names[#names + 1] = instrument.name end
    print(string.format("  %s | %s | %d notes", player.name, table.concat(names, ", "), count))
  end

  print("  most players playing at once: " .. mostAtOnce(spans))
end
