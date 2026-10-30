-- After note-names.lua was cancelled, undone, or asked only to remove its names: the reading fixture's own three texts
-- are there and no other text is. args.cancelled: it also said it changed nothing. args.removed: it said it removed a
-- name for each chord of every voice, the names the run before it wrote.
local checks = require("checks")

return function(p, run, args)
  if args.cancelled then p:check("said so", checks.printed(run, "Cancelled: nothing changed.")) end
  local s, _, values = checks.savedCopy()
  local own, others, chords = {}, {}, 0
  for _, want in ipairs(checks.reading().texts) do own[want.words] = false end
  for _, flow in ipairs(s.flows) do
    for _, e in ipairs(flow.events) do
      if e.kind == "text" and own[e.words] ~= nil then own[e.words] = true end
    end
    for _, stream in ipairs(flow.streams) do
      if stream.type == "voice" then
        local at = {}
        for _, e in ipairs(stream.events) do
          if e.kind == "text" and own[e.words] == nil then others[#others + 1] = e.words end
          if e.kind == "note" and not at[values.positionText(e.position)] then
            at[values.positionText(e.position)] = true
            chords = chords + 1
          end
        end
      end
    end
  end
  p:check("no names left", #others == 0, #others .. ": " .. table.concat(others, " | "):sub(1, 200))
  local missing = {}
  for words, found in pairs(own) do
    if not found then missing[#missing + 1] = words end
  end
  p:check("the fixture's own texts are there", #missing == 0, table.concat(missing, " | "))
  if args.removed then
    local said = string.format("Removed %d names.", chords)
    p:check("said how many", checks.printed(run, said), said .. " | " .. table.concat(run.printed, " / "))
  end
end
