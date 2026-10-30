-- After 11-flows-and-players.lua and one Edit > Undo, the flow and the player are gone and every name is exactly as
-- it was, the trumpet's B-flat token included.
local checks = require("checks")

return function(p)
  local want = checks.expected()
  local score = DoApp.DoApp().currentScore
  p:check("two flows again", #score.flows == 2, #score.flows)
  p:check("four players again", #score.players == 4, #score.players)
  for i, player in ipairs(want.flows[1].players) do
    p:check("player " .. i .. "'s name", tostring(score.players[i]) == player.name, tostring(score.players[i]))
  end
end
