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

  -- The most players sounding at once can only change where a note starts, so count at each start.
  local most = 0
  for _, list in pairs(spans) do
    for _, span in ipairs(list) do
      local at, playing = span[1], 0
      for _, other in pairs(spans) do
        for _, o in ipairs(other) do
          if o[1] <= at and at < o[2] then
            playing = playing + 1
            break
          end
        end
      end
      if playing > most then most = playing end
    end
  end
  print("  most players playing at once: " .. most)
end
