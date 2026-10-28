-- Run with 14-key-command.lua in a later script run: the count went up by one, so the global outlived the run.
return function(p, run)
  local before = DoricoExamplesTestKeyCommandCount
  p:check("the count went up by one", before and run.printed[1] == "run " .. (before + 1) .. " since Dorico started",
    tostring(before) .. " then " .. tostring(run.printed[1]))
end
