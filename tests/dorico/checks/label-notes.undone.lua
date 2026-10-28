-- After label-notes.lua and one Edit > Undo, the labels are gone.
local checks = require("checks")

return function(p)
  p:check("no labels left", #checks.texts(1) == 0, checks.joined(checks.texts(1)))
  checks.musicUnchanged(p)
end
