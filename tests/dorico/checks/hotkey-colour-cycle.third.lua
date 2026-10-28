-- After hotkey-colour-cycle.lua and two quick reruns through Script.RunLastScript (as Ctrl+Shift+Alt+R would), the
-- cycle has reached the third colour.
return function(p)
  local state = DoricoExamplesColourCycle
  p:check("at the third colour", state and state.index == 3, state and state.index)
end
