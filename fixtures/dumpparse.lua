-- stream:dump() text as event tables, for the sample project's build and check scripts (the examples carry their
-- own copy of this, as the "dump" helper). Each event line is "<pos> (<pos>)[ dur: <d>]: <tostring(event)>".
local dumpparse = {}

local KINDS = {
  kNoteEvent = "note", kGraceNoteEvent = "grace", kRestEvent = "rest", kBarRestEvent = "rest", kTextEvent = "text",
}

-- "13/2 (6.5)" -> 6.5, "4" -> 4: an exact fraction wins over the rounded decimal.
local function number(s)
  local raw = s and s:match("^([%-%d%./]+)")
  if not raw then return nil end
  local a, b = raw:match("^(%-?%d+)/(%d+)$")
  if a then return tonumber(a) / tonumber(b) end
  return tonumber(raw)
end

local SPELLING = "[A-G][#bx]*%-?%d+"

local function event(line, instance)
  local s = line:match(": (k%a+ %(id:%d+%).*)$")
  if not s then return nil end
  local ev = { kind = KINDS[s:match("^(k%a+)")] or "other", raw = s, instance = instance }
  ev.id = tonumber(s:match("%(id:(%d+)%)"))
  ev.pos = number(s:match(" at (%S+)"))
  ev.duration = number(s:match(", duration (%S+)"))
  if ev.kind == "note" then
    ev.spelling = s:match("%s(" .. SPELLING .. ") %(ends")
  elseif ev.kind == "grace" then
    ev.spelling = s:match(",%s*(" .. SPELLING .. ")%s*$")
    ev.duration = nil
  elseif ev.kind == "text" then
    ev.text = s:match(" : (.*)$")
  end
  return ev
end

function dumpparse.parse(text)
  local out, instance = { events = {} }, nil
  for line in (text or ""):gmatch("[^\n]+") do
    local start = line:match("^Start block id: (%d+)")
    if start then
      instance = tonumber(start)
    else
      local ev = event(line, instance)
      if ev then out.events[#out.events + 1] = ev end
    end
  end
  return out
end

-- The EventBlockID EventEdit.Select takes: the id of the block whose instance holds the event.
function dumpparse.blockIdOf(stream, eventId, parsed)
  local instance
  for _, ev in ipairs(parsed.events) do
    if ev.id == eventId then instance = ev.instance end
  end
  for _, bi in ipairs(stream.blockInstances) do
    if bi.id == instance then return bi.block.id end
  end
  error("no block for event " .. tostring(eventId))
end

-- {[voice stream id] = player name}: flow.instruments[i] owns flow.voiceStreams[i], and a player's name is
-- tostring(player).
function dumpparse.owners(score, flow)
  local nameOf = {}
  for _, pl in ipairs(score.players) do
    for _, ins in ipairs(pl.instruments) do nameOf[ins.id] = tostring(pl) end
  end
  local owners = {}
  for i, s in ipairs(flow.voiceStreams) do owners[s.id] = nameOf[flow.instruments[i].id] end
  return owners
end

return dumpparse
