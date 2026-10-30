-- After 10-commands.lua and one Edit > Undo, the first flow has its old title back.
local checks = require("checks")

return function(p)
  local titles = checks.flowTitles()
  p:check("the first flow's title is back", titles[1] == "Sample", titles[1])
end
