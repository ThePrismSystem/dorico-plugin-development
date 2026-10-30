-- Walk the score: players, flows, and which player each voice belongs to.
-- What it does: prints every player's name, then each flow with its players and voices, naming the player each
-- voice belongs to.
-- Changes: nothing (read-only).
-- Undo: nothing to undo.
-- Builds on: 01-hello.lua. Open Script > Show Script Console to read what it prints.

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

local app, score = guard()
if not score then return end

-- tostring(player) is the player's name as the Setup panel shows it, except that Dorico's music symbols come out
-- as tokens: a B-flat trumpet's name ends "(B{@flat@})".
for _, player in ipairs(score.players) do
  print("player: " .. tostring(player))
end

-- Players have no id that Lua can see, and comparing two players with == raises an error. Their first instrument's
-- id is unique and stays the same, so it stands in for the player.
local playerOf = {}
for _, player in ipairs(score.players) do
  for _, instrument in ipairs(player.instruments) do playerOf[instrument.id] = tostring(player) end
end

-- A flow holds streams of events: a voice stream per voice, a stave stream per staff, a player stream per player
-- and one timebase stream. flow.instruments has one entry per voice stream, in the same order, and that entry is
-- the instrument whose voice it is.
for n, flow in ipairs(score.flows) do
  print(string.format("flow %d: %d players, %d voices, %d staves", n, #flow.players, #flow.voiceStreams,
    #flow.staveStreams))
  for i in ipairs(flow.voiceStreams) do
    print("  voice: " .. (playerOf[flow.instruments[i].id] or "?"))
  end
end
