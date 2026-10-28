-- hotkey-colour-cycle.lua printed the colour it used, the one its global says is current. The same check runs on
-- every rerun through Script.RunLastScript, so it pins nothing about which colour.
return function(p, run)
  local state = DoricoExamplesColourCycle
  p:check("printed the current colour", state and run.printed[1] == string.format("colour %d of 4: %s", state.index,
    ({ "#ffe41a1c", "#ff1f78b4", "#ff4daf4a", "#ffff7f00" })[state.index]), run.printed[1])
end
