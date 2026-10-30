-- Selects one note by id and leaves it selected, for drivers that then act through Dorico's own UI or check the
-- Remote API status. Scratch copy only.
--   args.player: the player's name as tostring(player) gives it (default "Piano")
--   args.pos: the note's position in quarter notes (default 0); args.flow: the flow's index (default 1)
local here = debug.getinfo(1, "S").source:match("^@(.*[/\\])")
local mine = here .. "?.lua;" .. here .. "lib/?.lua;" .. here .. "../fixtures/?.lua;" .. here .. "../lib/?.lua"
for name in pairs(package.loaded) do
  if package.searchpath(name, mine) then package.loaded[name] = nil end
end
if not package.path:find(mine, 1, true) then package.path = mine .. ";" .. package.path end
local probe = require("probe")

probe.run("select_note", function(p)
  local dump = require("scorereader.dorico.dump")
  local edit = require("scorereader.dorico.edit")
  local dumpparse = require("dumpparse")
  local app = DoApp.DoApp()
  local score = app.currentScore
  local flow = score.flows[p.args.flow or 1]
  local owners = dumpparse.owners(score, flow)
  local player, pos = p.args.player or "Piano", p.args.pos or 0
  for _, s in ipairs(flow.voiceStreams) do
    if owners[s.id] == player then
      local parsed = dump.parse(s:dump())
      for _, ev in ipairs(parsed.events) do
        if ev.kind == "note" and ev.pos == pos then
          app:doCommand("NoteInput.Exit")
          app:doCommand("Window.SwitchMode?WindowMode=kWriteMode")
          app:doCommand("Edit.SelectNone")
          app:doCommand(string.format("EventEdit.Select?FlowID=%d&EventID=%d&EventBlockID=%d", flow.id, ev.id,
            edit.blockIdOf(s, ev.id, parsed)))
          p:fact("selected", { stream = s.id, id = ev.id, spelling = ev.spelling })
          return
        end
      end
    end
  end
  p:check("a note to select", false, player .. " at " .. pos)
end)
