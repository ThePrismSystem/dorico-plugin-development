-- 14-key-command.lua printed its run count, kept in its global. The count is remembered here for
-- 14-key-command.again.lua, which runs in a later script run, in the same Lua state.
return function(p, run)
  local n = DoricoExamplesKeyCommandRuns
  p:check("printed the count", run.printed[1] == "run " .. tostring(n) .. " since Dorico started", run.printed[1])
  DoricoExamplesTestKeyCommandCount = n
end
