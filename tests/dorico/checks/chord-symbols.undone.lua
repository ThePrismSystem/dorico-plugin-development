-- After chord-symbols.lua and eleven presses of Edit > Undo, the sample's four chord symbols are gone.
local checks = require("checks")

return function(p)
  p:check("no chord symbols left", #checks.chordSymbols(1) == 0, checks.joined(checks.chordSymbols(1)))
  checks.musicUnchanged(p)
end
