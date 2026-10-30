-- Selects notes before an example runs, as a user would. Scratch copy only (the probe confirms it).
--   args.player, args.pos: the first note to select, in flow 1
--   args.extend: how many notes to the right to add to it, with EventEdit.NavigateRightExtend
--   args.renameSecondFlow: first rename flow 2 to "Edited before the run", an edit of the user's own (this run is an
--   undo step of its own, apart from the example's)
local here = debug.getinfo(1, "S").source:match("^@(.*[/\\])")
local repo = here .. "../../"
local mine = here .. "lib/?.lua;" .. repo .. "spikes/lib/?.lua;" .. repo .. "fixtures/?.lua;" .. repo .. "lib/?.lua"
for name in pairs(package.loaded) do
  if package.searchpath(name, mine) then package.loaded[name] = nil end
end
if not package.path:find(mine, 1, true) then package.path = mine .. ";" .. package.path end
local probe = require("probe")

probe.run("case_select", function(p)
  local dump = require("scorereader.dorico.dump")
  local edit = require("scorereader.dorico.edit")
  local dumpparse = require("dumpparse")
  local app = DoApp.DoApp()
  local score = app.currentScore
  if p.args.renameSecondFlow then
    app:doCommand(string.format("Project.Flow.Rename?FlowID=%d&Name=Edited before the run", score.flows[2].id))
  end
  local flow = score.flows[1]
  local owners = dumpparse.owners(score, flow)
  for _, s in ipairs(flow.voiceStreams) do
    if owners[s.id] == p.args.player then
      local parsed = dump.parse(s:dump())
      for _, ev in ipairs(parsed.events) do
        if ev.kind == "note" and ev.pos == p.args.pos then
          app:doCommand("NoteInput.Exit")
          app:doCommand("Window.SwitchMode?WindowMode=kWriteMode")
          app:doCommand("Edit.SelectNone")
          app:doCommand(string.format("EventEdit.Select?FlowID=%d&EventID=%d&EventBlockID=%d", flow.id, ev.id,
            edit.blockIdOf(s, ev.id, parsed)))
          for _ = 1, p.args.extend or 0 do app:doCommand("EventEdit.NavigateRightExtend") end
          p:fact("selectedFrom", { id = ev.id, spelling = ev.spelling })
          return
        end
      end
    end
  end
  p:check("a note to select", false, tostring(p.args.player) .. " at " .. tostring(p.args.pos))
end)
