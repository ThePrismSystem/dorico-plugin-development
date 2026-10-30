-- After find-and-replace.lua was cancelled or undone: the texts fixture's texts, lyrics and chord symbols are as they
-- were. args.cancelled: it also said it changed nothing.
local checks = require("checks")

return function(p, run, args)
  if args.cancelled then p:check("said so", checks.printed(run, "Cancelled: nothing changed.")) end
  local now, want = checks.textsNow()
  p:check("the texts, lyrics and chord symbols", now == want, "got " .. now .. " | want " .. want)
end
