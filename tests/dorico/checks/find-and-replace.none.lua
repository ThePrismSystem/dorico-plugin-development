-- After find-and-replace.lua was cancelled, undone, or stopped before changing anything: the texts fixture's texts,
-- lyrics and chord symbols are as they were. args.cancelled: it also said it changed nothing. args.said: it printed
-- this line. args.gone: the bars whose text a step after it deleted, which are gone, with the rest as they were.
local checks = require("checks")

return function(p, run, args)
  if args.cancelled then p:check("said so", checks.printed(run, "Cancelled: nothing changed.")) end
  if args.said then
    p:check("said why", checks.printed(run, args.said), args.said .. " | " .. table.concat(run.printed, " / "))
  end
  local now, want = checks.textsNow({ gone = args.gone })
  p:check("the texts, lyrics and chord symbols", now == want, "got " .. now .. " | want " .. want)
end
