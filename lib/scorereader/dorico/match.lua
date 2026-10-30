-- Setting Lua's view of a stream beside the decoded score. Stream ids and event ids are the same on both sides, so a
-- match is by id, with the position, a note's spelling and a text's words checked too.
local values = require("scorereader.values")

local match = {}

-- For the stream streamId in flow flowId: {byId = {[id] = {file = Event, lua = dump event}}, count, unmatched =
-- {reason}}. parsed is scorereader.dorico.dump.parse(stream:dump()). Each of these gives a reason: an event Lua lists
-- that the file lacks, one at another position, a note spelled differently, a text with other words, and an event the
-- file has that Lua didn't list.
function match.stream(s, flowId, streamId, parsed)
  local fileEvents
  for _, flow in ipairs(s.flows) do
    if flow.id == flowId and flow.streamById[streamId] then fileEvents = flow.streamById[streamId].events end
  end
  local out = { byId = {}, count = 0, unmatched = {} }
  if not fileEvents then
    out.unmatched[1] = "the file has no stream " .. streamId .. " in flow " .. flowId
    return out
  end
  local left = {}
  for _, e in ipairs(fileEvents) do left[e.id] = e end
  for _, ev in ipairs(parsed.events) do
    local e = left[ev.id]
    -- The dump line holds only a text's first paragraph.
    local firstLine = e and e.words and e.words:match("^[^\n]*")
    if not e then
      out.unmatched[#out.unmatched + 1] = "Lua lists event " .. ev.id .. ", the file doesn't"
    elseif ev.pos and math.abs(ev.pos - values.toNumber(e.position)) > 1e-9 then
      out.unmatched[#out.unmatched + 1] = "event " .. ev.id .. " is at " .. ev.pos .. " in Lua and "
        .. values.positionText(e.position) .. " in the file"
      left[ev.id] = nil
    elseif ev.spelling and ev.spelling ~= e.spelling then
      out.unmatched[#out.unmatched + 1] = "event " .. ev.id .. " is spelled " .. ev.spelling .. " in Lua and "
        .. tostring(e.spelling) .. " in the file"
      left[ev.id] = nil
    elseif ev.text and firstLine and ev.text ~= firstLine then
      out.unmatched[#out.unmatched + 1] = "event " .. ev.id .. " says \"" .. ev.text .. "\" in Lua and \"" .. firstLine
        .. "\" in the file"
      left[ev.id] = nil
    else
      out.byId[ev.id] = { file = e, lua = ev }
      out.count = out.count + 1
      left[ev.id] = nil
    end
  end
  for id, e in pairs(left) do
    out.unmatched[#out.unmatched + 1] = "the file has event " .. id .. " (" .. e.definition .. "), Lua doesn't"
  end
  return out
end

return match
