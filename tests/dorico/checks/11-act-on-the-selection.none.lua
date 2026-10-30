-- 11-act-on-the-selection.lua with nothing selected said so, added nothing and changed no note.
local checks = require("checks")

return function(p, run)
  p:check("said to select notes first", run.printed[1] == "Select one or more notes first, then run this script again."
    and #run.printed == 1, table.concat(run.printed, " / "))
  p:check("added no text", #checks.texts(1) == 0 and #checks.texts(2) == 0, checks.joined(checks.texts(1)))
  checks.musicUnchanged(p)
end
