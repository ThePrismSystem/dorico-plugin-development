-- Players, layouts and options on the sample, scratch copy only (the probe confirms it). args.step picks what to do:
--   "look": report the layouts (id, player count), flows (id) and players (name, first instrument id)
--   "change": add a violin player, find its player id by renaming candidates, rename it, take it out of flow 2,
--             add a flow, then report as "look" does
local here = debug.getinfo(1, "S").source:match("^@(.*[/\\])")
local mine = here .. "?.lua;" .. here .. "lib/?.lua"
for name in pairs(package.loaded) do
  if package.searchpath(name, mine) then package.loaded[name] = nil end
end
if not package.path:find(mine, 1, true) then package.path = mine .. ";" .. package.path end
local probe = require("probe")

local function look(p, score)
  local layouts, flows, players = {}, {}, {}
  for _, l in ipairs(score.layouts) do layouts[#layouts + 1] = { id = l.id, players = #l.players } end
  for _, f in ipairs(score.flows) do
    local names = {}
    for _, pl in ipairs(f.players) do names[#names + 1] = tostring(pl) end
    flows[#flows + 1] = { id = f.id, players = names }
  end
  for _, pl in ipairs(score.players) do players[#players + 1] = { name = tostring(pl), first = pl.instruments[1].id } end
  p:fact("layouts", layouts)
  p:fact("flows", flows)
  p:fact("players", players)
  p:fact("openScoreID", score.openScoreID)
  p:fact("currentLayoutID", DoApp.DoApp().currentLayoutID)
end

probe.run("players_and_options", function(p)
  local app = DoApp.DoApp()
  local score = app.currentScore
  if p.args.step == "change" then
    local before = #score.players
    local added = score:addPlayer("instrument.strings.violin", false, 1)
    p:fact("addPlayerReturned", tostring(added))
    p:check("a player was added", #app.currentScore.players == before + 1, #app.currentScore.players)
    local newest = app.currentScore.players[#app.currentScore.players]
    local key = newest.instruments[1].id
    p:fact("newPlayer", { name = tostring(newest), first = key })
    local names = {}
    for _, pl in ipairs(app.currentScore.players) do names[pl.instruments[1].id] = tostring(pl) end
    local function escape(s) return (s:gsub("\\", "\\\\"):gsub("&", "\\&")) end
    local found, others = nil, {}
    for id = 0, 200 do
      app:doCommand(string.format("Project.Player.Rename?PlayerID=%d&Name=PROBEID%d", id, id))
      for _, pl in ipairs(app.currentScore.players) do
        if tostring(pl) == "PROBEID" .. id then
          local k = pl.instruments[1].id
          if k == key then found = id end
          app:doCommand(string.format("Project.Player.Rename?PlayerID=%d&Name=%s", id, escape(names[k])))
          others[#others + 1] = id .. "=" .. names[k] .. " -> " .. tostring(pl)
        end
      end
      if found then break end
    end
    p:fact("playerId", found)
    p:fact("renamedOnTheWay", others)
    local after = {}
    for _, pl in ipairs(app.currentScore.players) do after[#after + 1] = tostring(pl) end
    p:fact("namesAfterSearch", after)
    if found then
      app:doCommand(string.format("Project.Player.Rename?PlayerID=%d&Name=Violin, solo \\& tutti 2", found))
    end
    for _, pl in ipairs(app.currentScore.players) do
      if pl.instruments[1].id == key then app.currentScore.flows[2]:removePlayer(pl) end
    end
    app:doCommand("Project.Flow.New")
  end
  look(p, app.currentScore)
end)
