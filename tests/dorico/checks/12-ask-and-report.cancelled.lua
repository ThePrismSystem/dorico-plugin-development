-- 12-ask-and-report.lua with its box cancelled said so and changed nothing.
local checks = require("checks")

return function(p, run)
  p:check("said it was cancelled", run.printed[1] == "Cancelled: nothing changed." and #run.printed == 1,
    table.concat(run.printed, " / "))
  p:check("two flows still", #DoApp.DoApp().currentScore.flows == 2, #DoApp.DoApp().currentScore.flows)
  checks.musicUnchanged(p)
end
