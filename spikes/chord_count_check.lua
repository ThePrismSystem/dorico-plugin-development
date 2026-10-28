-- A check-only case for spikes/chord_undo.py: reports the chord symbols in flow 1 and passes.
local checks = require("checks")

return function(p)
  p:fact("chords", checks.joined(checks.chordSymbols(1)))
end
