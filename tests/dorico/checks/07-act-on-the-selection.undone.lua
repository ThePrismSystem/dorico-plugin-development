-- After 07-act-on-the-selection.lua and one Edit > Undo, the labels are gone, every note is as it was, and the edit
-- made before the run (the second flow's new title) is still there.
local checks = require("checks")

return function(p)
  p:check("no labels left", #checks.texts(1) == 0, checks.joined(checks.texts(1)))
  p:check("the earlier edit is untouched", checks.flowTitles()[2] == "Edited before the run", checks.flowTitles()[2])
  checks.musicUnchanged(p)
end
