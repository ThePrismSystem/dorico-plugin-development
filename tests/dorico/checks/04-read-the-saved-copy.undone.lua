-- After case_edit.lua renamed flow 2, 04-read-the-saved-copy.lua ran, and one Edit > Undo: the undo took back the
-- rename, so 04 left no undo step of its own.
local checks = require("checks")

return function(p)
  local title = checks.flowTitles()[2]
  p:check("flow 2 has its title back", title == checks.expected().flows[2].title, title)
end
