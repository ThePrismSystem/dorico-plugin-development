-- S8: which note properties can a script read and set, and how? Works on the sample's trumpet, whose voice stream
-- holds only notes, so stream.events lists them and each change can be read straight back. Each command form is
-- tried on its own note, selected by id. Scratch copy only.
local here = debug.getinfo(1, "S").source:match("^@(.*[/\\])")
local mine = here .. "?.lua;" .. here .. "lib/?.lua;" .. here .. "../fixtures/?.lua"
for name in pairs(package.loaded) do
  if package.searchpath(name, mine) then package.loaded[name] = nil end
end
if not package.path:find(mine, 1, true) then package.path = mine .. ";" .. package.path end
local probe = require("probe")

local TRIES = {
  { pos = 0, command = 'UI.InvokePropertyChangeValue?Type=kEventColour&Value=string: "#ffff0000"' },
  { pos = 1, command = "UI.InvokePropertyChangeValue?Type=kEventColour&Value=#ff00ff00" },
  { pos = 2, command = 'UI.InvokePropertyChangeValue?Type=kEventColour&Value=string: "#0000ff"' },
  { pos = 4, command = 'UI.InvokePropertyChangeValue?Type=kNoteheadSetOverride&Value=string: "noteheadset.diamondNoteheads"' },
}

probe.run("s8_properties", function(p)
  local dumpparse = require("dumpparse")
  local app = DoApp.DoApp()
  local score = app.currentScore
  local flow = score.flows[1]
  local owners = dumpparse.owners(score, flow)
  local trumpet
  for _, s in ipairs(flow.voiceStreams) do
    if not trumpet and owners[s.id] and owners[s.id]:find("^Trumpet") then trumpet = s end
  end
  if not p:check("a trumpet voice", trumpet ~= nil) then return end
  local ctx = DoCore.PropertyContext()
  local function noteAt(pos)
    for _, e in ipairs(trumpet.events) do
      if tostring(e):match("^kNoteEvent") and tonumber(tostring(e):match(" at (%d+)")) == pos then return e end
    end
  end
  local function props(e)
    local out = {}
    for _, n in ipairs(e.propertyTable:getPropertyNames()) do
      out[tostring(n)] = tostring(e.propertyTable:get(n, ctx))
    end
    return out
  end
  p:fact("before", props(noteAt(0)))

  app:doCommand("NoteInput.Exit")
  app:doCommand("Window.SwitchMode?WindowMode=kWriteMode")
  local results = {}
  for _, try in ipairs(TRIES) do
    local e = noteAt(try.pos)
    local parsed = dumpparse.parse(trumpet:dump())
    app:doCommand("Edit.SelectNone")
    app:doCommand(string.format("EventEdit.Select?FlowID=%d&EventID=%d&EventBlockID=%d", flow.id, e.id,
      dumpparse.blockIdOf(trumpet, e.id, parsed)))
    app:doCommand(try.command)
    app:doCommand("Edit.SelectNone")
    results[#results + 1] = { command = try.command, after = props(noteAt(try.pos)) }
  end
  -- and through the object model, on a note the commands didn't touch
  local direct = noteAt(3)
  local ok = direct.propertyTable:set("kEventColour", DoCore.Variant.createString("#ff8000ff"), ctx)
  results[#results + 1] = { command = "propertyTable:set kEventColour", returned = tostring(ok), after = props(noteAt(3)) }
  p:fact("results", results)
end)
