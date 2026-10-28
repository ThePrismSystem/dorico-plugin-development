-- S8, reading a colour back: a colour set by command reads back as "" through tostring(variant). What else does the
-- Variant (and the property table's entries) offer? Colours the trumpet's first note by command, then reads it
-- every way it can find. Scratch copy only.
local here = debug.getinfo(1, "S").source:match("^@(.*[/\\])")
local mine = here .. "?.lua;" .. here .. "lib/?.lua;" .. here .. "../fixtures/?.lua"
for name in pairs(package.loaded) do
  if package.searchpath(name, mine) then package.loaded[name] = nil end
end
if not package.path:find(mine, 1, true) then package.path = mine .. ";" .. package.path end
local probe = require("probe")

local function try(fn)
  local ok, v = pcall(fn)
  if not ok then return "error: " .. tostring(v):sub(1, 120) end
  if v == nil then return "nil" end
  local okS, s = pcall(tostring, v)
  return okS and (type(v) .. ": " .. s) or ("unprintable " .. type(v))
end

probe.run("s8_colour_read", function(p)
  local dumpparse = require("dumpparse")
  local app = DoApp.DoApp()
  local score = app.currentScore
  local flow = score.flows[1]
  local owners = dumpparse.owners(score, flow)
  local trumpet
  for _, s in ipairs(flow.voiceStreams) do
    if not trumpet and owners[s.id] and owners[s.id]:find("^Trumpet") then trumpet = s end
  end
  local note
  for _, e in ipairs(trumpet.events) do
    if not note and tostring(e):match("^kNoteEvent") then note = e end
  end
  local parsed = dumpparse.parse(trumpet:dump())
  app:doCommand("Edit.SelectNone")
  app:doCommand(string.format("EventEdit.Select?FlowID=%d&EventID=%d&EventBlockID=%d", flow.id, note.id,
    dumpparse.blockIdOf(trumpet, note.id, parsed)))
  app:doCommand("UI.InvokePropertyChangeValue?Type=kEventColour&Value=#ffff0000")
  app:doCommand("Edit.SelectNone")
  for _, e in ipairs(trumpet.events) do
    if e.id == note.id then note = e end
  end
  local ctx = DoCore.PropertyContext()
  local v = note.propertyTable:get("kEventColour", ctx)
  local out = { tostring = try(function() return tostring(v) end) }
  for _, name in ipairs({ "value", "type", "string", "asString", "toString", "getString", "isValid", "valid",
    "colour", "color", "rgba", "argb", "name", "context", "data" }) do
    out["." .. name] = try(function() return v[name] end)
    out[":" .. name .. "()"] = try(function() return v[name](v) end)
  end
  local entries = try(function() return note.propertyTable.entries end)
  out.entries = entries
  out.tableLen = try(function() return #note.propertyTable end)
  out.tableToString = try(function() return tostring(note.propertyTable) end)
  p:fact("read", out)
end)
