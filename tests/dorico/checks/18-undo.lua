-- 18-undo.lua saw its one Edit.Undo take back both its command edit and its object-model edit, and that undo left
-- alone the edit made in the run before it (the second flow's new title).
local checks = require("checks")

local SAID = {
  "flows at the start: 2",
  "flows after Project.Flow.New: 3",
  "text after createText: there",
  "flows after Edit.Undo: 2",
  "text after Edit.Undo: gone",
}

return function(p, run)
  p:check("printed what happened", table.concat(run.printed, " / ") == table.concat(SAID, " / "),
    table.concat(run.printed, " / "))
  p:check("no text left", #checks.texts(1) == 0, checks.joined(checks.texts(1)))
  p:check("the earlier edit is untouched", checks.flowTitles()[2] == "Edited before the run", checks.flowTitles()[2])
  checks.musicUnchanged(p)
end
