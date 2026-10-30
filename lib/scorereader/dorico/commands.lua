-- Command strings for app:doCommand, "Name?key=value&key=value". Dorico reads a backslash in a value as an escape, and
-- a bare "&" or "," ends the value, so a value's own backslashes, ampersands and commas each get a backslash in front;
-- "=" and any other character pass as they are. A nil value is refused, since tostring would send the word "nil".
local commands = {}

function commands.value(v)
  if v == nil then error("a command parameter has no value", 2) end
  return (tostring(v):gsub("\\", "\\\\"):gsub("&", "\\&"):gsub(",", "\\,"))
end

-- params: a list of {key, value} pairs, in the order Dorico should get them.
function commands.build(name, params)
  local parts = {}
  for i, kv in ipairs(params or {}) do parts[i] = kv[1] .. "=" .. commands.value(kv[2]) end
  if #parts == 0 then return name end
  return name .. "?" .. table.concat(parts, "&")
end

-- Selects one event, replacing the selection. blockId is the id of the block holding it, which the decoded score
-- gives as event.blockId; a select with the wrong block id selects nothing and reports nothing.
function commands.select(flowId, eventId, blockId)
  return commands.build("EventEdit.Select", { { "FlowID", flowId }, { "EventID", eventId }, { "EventBlockID", blockId } })
end

-- Sets a property on one event by its ids, with nothing selected. Dorico stores the value with no context, so it
-- applies in every layout.
function commands.changeProperty(flowId, eventId, blockId, property, value)
  return commands.build("EventEdit.ChangeProperty", { { "FlowID", flowId }, { "EventID", eventId },
    { "EventBlockID", blockId }, { "Type", property }, { "Value", value } })
end

return commands
