-- Acting on an event the decoded score found, through Dorico's commands. An event from scorereader.score carries its
-- flowId, id and blockId, which is everything EventEdit.Select and EventEdit.ChangeProperty need.
local commands = require("scorereader.dorico.commands")

---@class scorereader.dorico.edit
local edit = {}

-- Selects the event alone.
function edit.select(app, e)
  app:doCommand("Edit.SelectNone")
  app:doCommand(commands.select(e.flowId, e.id, e.blockId))
end

-- Sets a property on the event with nothing selected. Dorico stores it for every layout, and it joins the script
-- run's one undo step.
function edit.setProperty(app, e, property, value)
  app:doCommand(commands.changeProperty(e.flowId, e.id, e.blockId, property, value))
end

-- Takes a property off the event, whatever value it had.
function edit.removeProperty(app, e, property)
  app:doCommand(commands.removeProperty(e.flowId, e.id, e.blockId, property))
end

-- Deletes the event. Tried on texts, lyrics and chord symbols (docs/spikes.md, W1 to W3).
function edit.delete(app, e)
  edit.select(app, e)
  app:doCommand("Edit.Delete")
end

-- The EventEdit.Select block id for an event in a Lua stream, from a parsed dump: the dump's "Start block id" is an
-- instance id, and the instance's block carries the id. For an event the decoded score found, use its blockId.
function edit.blockIdOf(stream, eventId, parsed)
  local instance
  for _, ev in ipairs(parsed.events) do
    if ev.id == eventId then instance = ev.instance end
  end
  for _, bi in ipairs(stream.blockInstances) do
    if bi.id == instance then return bi.block.id end
  end
  error("scorereader: no block holds event " .. tostring(eventId), 0)
end

return edit
