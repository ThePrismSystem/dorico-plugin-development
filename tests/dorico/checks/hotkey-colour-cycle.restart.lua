-- hotkey-colour-cycle.lua run after a pause longer than its window starts again at the first colour.
return function(p, run)
  p:check("back to the first colour", run.printed[1] == "colour 1 of 4: #ffe41a1c", run.printed[1])
end
