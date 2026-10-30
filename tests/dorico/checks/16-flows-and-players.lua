-- 16-flows-and-players.lua added the flow and the player, gave the player its name with the comma and ampersand
-- intact, kept it to the new flow, and touched no other player's name.
local checks = require("checks")

return function(p, run)
  local want = checks.expected()
  local score = DoApp.DoApp().currentScore
  p:check("said it added the flow", run.printed[1] == 'added flow 3: "Duet"', run.printed[1])
  p:check("said it added the player", run.printed[2] == "added player Violin, solo & tutti 2 (player id 4)",
    run.printed[2])
  p:check("said where the player is", run.printed[3] == "the new player is in flow 3", run.printed[3])
  p:check("five players", #score.players == 5, #score.players)
  p:check("the new player's name", tostring(score.players[5]) == "Violin, solo & tutti 2", tostring(score.players[5]))
  for i, player in ipairs(want.flows[1].players) do
    p:check("player " .. i .. " keeps its name", tostring(score.players[i]) == player.name, tostring(score.players[i]))
  end
  p:check("the new flow's title", checks.flowTitles()[3] == "Duet", checks.flowTitles()[3])
  for n, flow in ipairs(score.flows) do
    p:check("flow " .. n .. " players", #flow.players == (n == 3 and 5 or 4), #flow.players)
  end
end
