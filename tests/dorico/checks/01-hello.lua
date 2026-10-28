-- 01-hello.lua printed Dorico's version and the sample's title, flow count and player count.
local checks = require("checks")

return function(p, run)
  local want = checks.expected()
  local printed = run.printed
  p:check("printed Dorico's version", printed[1] == "Dorico " .. DoApp.DoApp().versionString, printed[1])
  p:check("printed the project's title", printed[2] == "project: Sample", printed[2])
  p:check("printed the flow count", printed[3] == "flows: " .. #want.flows, printed[3])
  p:check("printed the player count", printed[4] == "players: " .. #want.flows[1].players, printed[4])
  p:check("printed nothing else", #printed == 4, #printed)
end
