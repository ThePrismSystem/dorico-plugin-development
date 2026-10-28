-- S3, the gap: can a script make a bar with removed rests, and does the dump show it? Selects the trumpet's note at
-- bar 5 beat 1, tries to reach the implicit rest after it, runs Edit.RemoveRests, and dumps every stream of the flow
-- before and after (to <run folder>/s3-gap.txt). Scratch copy only.
--   args.attempt: "right" (EventEdit.NavigateRight) or "extend" (EventEdit.NavigateRightExtend)
local here = debug.getinfo(1, "S").source:match("^@(.*[/\\])")
local mine = here .. "?.lua;" .. here .. "lib/?.lua;" .. here .. "../fixtures/?.lua"
for name in pairs(package.loaded) do
  if package.searchpath(name, mine) then package.loaded[name] = nil end
end
if not package.path:find(mine, 1, true) then package.path = mine .. ";" .. package.path end
local probe = require("probe")

probe.run("s3_gap", function(p)
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
  local out = assert(io.open(probe.runDir .. "s3-gap.txt", "wb"))
  local function record(label)
    out:write("=== ", label, " ===\n")
    for _, s in ipairs(flow.allStreams) do
      out:write("--- stream ", s.id, "\n", s:dump(), "\n")
    end
  end
  record("before")
  local parsed = dumpparse.parse(trumpet:dump())
  local note
  for _, ev in ipairs(parsed.events) do
    if ev.kind == "note" and ev.pos == 16 then note = ev end
  end
  if not p:check("the trumpet's note at bar 5", note ~= nil) then out:close() return end
  app:doCommand("NoteInput.Exit")
  app:doCommand("Window.SwitchMode?WindowMode=kWriteMode")
  app:doCommand("Edit.SelectNone")
  app:doCommand(string.format("EventEdit.Select?FlowID=%d&EventID=%d&EventBlockID=%d", flow.id, note.id,
    dumpparse.blockIdOf(trumpet, note.id, parsed)))
  app:doCommand(p.args.attempt == "extend" and "EventEdit.NavigateRightExtend" or "EventEdit.NavigateRight")
  app:doCommand("Edit.RemoveRests")
  app:doCommand("Edit.SelectNone")
  record("after " .. tostring(p.args.attempt))
  out:close()
  local kinds = {}
  for _, ev in ipairs(dumpparse.parse(trumpet:dump()).events) do kinds[#kinds + 1] = ev.raw:sub(1, 90) end
  p:fact("trumpetAfter", kinds)
end)
