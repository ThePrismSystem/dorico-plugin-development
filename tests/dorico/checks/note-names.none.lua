-- After note-names.lua was cancelled, undone, or asked only to remove its names: the reading fixture's voices hold no
-- texts but its own three. args.cancelled: it also said it changed nothing.
local checks = require("checks")

return function(p, run, args)
  if args.cancelled then p:check("said so", checks.printed(run, "Cancelled: nothing changed.")) end
  local s = checks.savedCopy()
  local own, others = {}, {}
  for _, want in ipairs(checks.reading().texts) do own[want.words] = true end
  for _, flow in ipairs(s.flows) do
    for _, stream in ipairs(flow.streams) do
      if stream.type == "voice" then
        for _, e in ipairs(stream.events) do
          if e.kind == "text" and not own[e.words] then others[#others + 1] = e.words end
        end
      end
    end
  end
  p:check("no names left", #others == 0, #others .. ": " .. table.concat(others, " | "):sub(1, 200))
end
