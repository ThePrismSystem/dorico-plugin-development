-- After chord-symbols.lua and one Edit > Undo, all four chord symbols are still there: the popover's commands make
-- undo steps of their own, three to a chord symbol.
local checks = require("checks")

return function(p)
  p:check("four chord symbols still", #checks.chordSymbols(1) == 4, checks.joined(checks.chordSymbols(1)))
end
