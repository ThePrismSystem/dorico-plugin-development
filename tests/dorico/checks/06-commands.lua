-- 06-commands.lua renamed the first flow, ampersand, equals sign and accented letter intact, and printed the command
-- with the ampersand escaped.
local checks = require("checks")

return function(p, run)
  local id = DoApp.DoApp().currentScore.flows[1].id
  p:check("printed the command", run.printed[1] == "sent: Project.Flow.Rename?FlowID=" .. id
    .. "&Name=Études \\& Sketches (A=440)", run.printed[1])
  local titles = checks.flowTitles()
  p:check("the first flow has the new title", titles[1] == "Études & Sketches (A=440)", titles[1])
  p:check("the second flow kept its title", titles[2] == "Second movement", titles[2])
end
