-- Add a flow and a player, name both, and keep the new player out of the other flows.
-- What it does: adds a flow called "Duet", adds a violin player, renames it "Violin, solo & tutti 2", and takes it
-- out of every flow but the new one. It prints what it added, the player id it found, and which flows the new
-- player is in. In a project with a player that has no instrument, it says so and changes nothing.
-- Changes: adds a flow and a player (and the part layout Dorico makes for a new player).
-- Undo: Edit > Undo takes all of it back in one step.
-- Builds on: 02-walk-the-score.lua and 10-commands.lua. Open Script > Show Script Console to read what it prints.
--
-- score:addPlayer(instrument, false, 1) adds a player with that instrument and returns it. The instrument is one of
-- the entityID values in instruments.xml, in Dorico's program folder, such as instrument.strings.violin. Pass only
-- ids listed there: a constructor given something it doesn't expect can crash Dorico. The new player joins every
-- flow, and flow:removePlayer(player) takes it out of one.
--
-- Commands that act on a player, such as Project.Player.Rename, take its player id, and Lua doesn't give players
-- an id. The script finds it by renaming: give a candidate id a name no player has, and see which player takes it.
-- In a project made in Dorico a player's id is usually its first instrument's id, so that's the first candidate.
-- If that fails, it tries every id in turn and puts back the name of each player it renames along the way. When it
-- renames other players like this, undoing the run later can bring back a transposing player's name in another
-- spelling, such as "Trumpet (B Flat)" for "Trumpet (B{@flat@})".

local FLOW_TITLE = "Duet"
local INSTRUMENT = "instrument.strings.violin"
local PLAYER_NAME = "Violin, solo & tutti 2"

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

-- helper: commands
-- Builds a command string, "Name?key=value&key=value", for app:doCommand. Dorico reads a backslash in a value as an
-- escape, and a bare "&" or "," ends the value, so a value's own backslashes, ampersands and commas each get a
-- backslash in front; "=" and any other character pass as they are. A nil value is refused, since tostring would
-- send Dorico the word "nil". Only single ids have been tried in list parameters such as FlowIDArray; given several,
-- as "1,2", this would escape the commas between them.
--   commands.value(v) -> v escaped
--   commands.build(name, params) -> the command, params a list of {key, value} pairs
local commands = {}
do
  function commands.value(v)
    if v == nil then error("a command parameter has no value", 2) end
    return (tostring(v):gsub("\\", "\\\\"):gsub("&", "\\&"):gsub(",", "\\,"))
  end

  function commands.build(name, params)
    local parts = {}
    for i, kv in ipairs(params or {}) do parts[i] = kv[1] .. "=" .. commands.value(kv[2]) end
    if #parts == 0 then return name end
    return name .. "?" .. table.concat(parts, "&")
  end
end
-- end helper: commands

local app, score = guard()
if not score then return end

-- Players have no ==, so a player is known by its first instrument's id, which is unique and doesn't change.
local function keyOf(player) return player.instruments[1].id end

-- A player with no instruments has no key. The search for the new player's id below can rename any player, and
-- couldn't put such a player's name back, so the script stops before it changes anything.
for _, player in ipairs(score.players) do
  if not player.instruments[1] then
    print(tostring(player) .. " has no instrument, and this script tells players apart by their first instrument. Give"
      .. " it one, then run this script again.")
    return
  end
end

local function playerByKey(key)
  for _, player in ipairs(app.currentScore.players) do
    if keyOf(player) == key then return player end
  end
end

local function rename(id, name)
  app:doCommand(commands.build("Project.Player.Rename", { { "PlayerID", id }, { "Name", name } }))
end

-- The player id of the player whose key is given, or nil.
local function playerIdOf(key)
  local TOKEN = "player-id-probe-"
  local function try(id)
    rename(id, TOKEN .. id)
    for _, player in ipairs(app.currentScore.players) do
      if tostring(player) == TOKEN .. id then return player end
    end
  end
  local names = {}
  for _, player in ipairs(app.currentScore.players) do names[keyOf(player)] = tostring(player) end
  local candidates = { key }
  for id = 0, 8 * #app.currentScore.players + 64 do
    if id ~= key then candidates[#candidates + 1] = id end
  end
  for _, id in ipairs(candidates) do
    local took = try(id)
    if took then
      rename(id, names[keyOf(took)])
      if keyOf(took) == key then return id end
    end
  end
end

-- A flow at the end, found as the id that wasn't there before.
local before = {}
for _, flow in ipairs(score.flows) do before[flow.id] = true end
app:doCommand("Project.Flow.New")
local newFlow, number
for n, flow in ipairs(app.currentScore.flows) do
  if not before[flow.id] then newFlow, number = flow, n end
end
if not newFlow then error("Project.Flow.New added no flow") end
app:doCommand(commands.build("Project.Flow.Rename", { { "FlowID", newFlow.id }, { "Name", FLOW_TITLE } }))
print(string.format('added flow %d: "%s"', number, FLOW_TITLE))

local key = keyOf(app.currentScore:addPlayer(INSTRUMENT, false, 1))
local id = playerIdOf(key)
if not id then error("no player id found for the new player") end
rename(id, PLAYER_NAME)
print(string.format("added player %s (player id %d)", tostring(playerByKey(key)), id))

for _, flow in ipairs(app.currentScore.flows) do
  if flow.id ~= newFlow.id then flow:removePlayer(playerByKey(key)) end
end
local inFlows = {}
for n, flow in ipairs(app.currentScore.flows) do
  for _, player in ipairs(flow.players) do
    if keyOf(player) == key then inFlows[#inFlows + 1] = tostring(n) end
  end
end
print("the new player is in flow " .. table.concat(inFlows, ", "))
