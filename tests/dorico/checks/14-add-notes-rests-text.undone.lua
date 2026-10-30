-- After 14-add-notes-rests-text.lua and one Edit > Undo, the new flow and its music are gone.
local checks = require("checks")

return function(p)
  local score = DoApp.DoApp().currentScore
  p:check("two flows again", #score.flows == 2, #score.flows)
  checks.musicUnchanged(p)
end
