-- stream:dump() as tables. Each event line reads "<pos> (<pos>)[ dur: <d>]: <event>", where <event> is what
-- tostring(event) gives, such as "kNoteEvent (id:7932) at 0, duration 1  E5 (ends 1)". A "Start block id:" line
-- starts each block instance (the id is an instance id, despite its name); the events after it belong to that
-- instance. Kinds are "note", "grace", "rest", "text" and "other"; positions and durations are quarter notes.
---@class scorereader.dorico.dump
local dump = {}

local KINDS = {
  kNoteEvent = "note", kGraceNoteEvent = "grace", kRestEvent = "rest", kBarRestEvent = "rest", kTextEvent = "text",
}
local SPELLING = "[A-G][#bx]*%-?%d+"

-- "13/2 (6.5)" gives 6.5 and "4" gives 4: the exact fraction, where there is one, beats the rounded decimal.
local function number(s)
  local raw = s and s:match("^([%-%d%./]+)")
  if not raw then return nil end
  local a, b = raw:match("^(%-?%d+)/(%d+)$")
  if a then return tonumber(a) / tonumber(b) end
  return tonumber(raw)
end

-- One event from tostring(event), or nil: {kind, id, pos, duration, spelling, grace, text, instance, raw}.
function dump.event(text, instance)
  local s = text and text:match("^(k%a+ %(id:%d+%).*)$")
  if not s then return nil end
  local ev = { kind = KINDS[s:match("^(k%a+)")] or "other", raw = s, instance = instance }
  ev.id = tonumber(s:match("%(id:(%d+)%)"))
  ev.pos = number(s:match(" at (%S+)"))
  ev.duration = number(s:match(", duration (%S+)"))
  ev.grace = ev.kind == "grace"
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

-- {events = {event}} for a stream's dump.
function dump.parse(text)
  local out, instance = { events = {} }, nil
  for line in (text or ""):gmatch("[^\r\n]+") do
    local start = line:match("^Start block id: (%d+)")
    if start then
      instance = tonumber(start)
    else
      local ev = dump.event(line:match(": (k%a+ %(id:%d+%).*)$"), instance)
      if ev then out.events[#out.events + 1] = ev end
    end
  end
  return out
end

-- The notes and grace notes of a parsed dump, and how many it left out because their lines have no spelling it reads.
function dump.notes(parsed)
  local notes, unread = {}, 0
  for _, ev in ipairs(parsed.events) do
    if (ev.kind == "note" or ev.kind == "grace") and ev.spelling then
      notes[#notes + 1] = ev
    elseif ev.kind == "note" or ev.kind == "grace" then
      unread = unread + 1
    end
  end
  return notes, unread
end

return dump
