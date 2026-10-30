-- Puts a chord symbol the user might already have before an example runs: "D" at the start of flow 1, through the
-- chord symbol popover's commands at the piano's first note. Scratch copy only (the probe confirms it).
local here = debug.getinfo(1, "S").source:match("^@(.*[/\\])")
local repo = here .. "../../"
local mine = here .. "lib/?.lua;" .. repo .. "spikes/lib/?.lua;" .. repo .. "fixtures/?.lua;" .. repo .. "lib/?.lua"
for name in pairs(package.loaded) do
  if package.searchpath(name, mine) then package.loaded[name] = nil end
end
if not package.path:find(mine, 1, true) then package.path = mine .. ";" .. package.path end
local probe = require("probe")

probe.run("case_chord", function(p)
  local dump = require("scorereader.dorico.dump")
  local edit = require("scorereader.dorico.edit")
  local dumpparse = require("dumpparse")
  local app = DoApp.DoApp()
  local score = app.currentScore
  local flow = score.flows[1]
  local owners = dumpparse.owners(score, flow)
  for _, s in ipairs(flow.voiceStreams) do
    if owners[s.id] == "Piano" then
      local parsed = dump.parse(s:dump())
      for _, ev in ipairs(parsed.events) do
        if ev.kind == "note" and ev.pos == 0 then
          app:doCommand("NoteInput.Exit")
          app:doCommand("Window.SwitchMode?WindowMode=kWriteMode")
          app:doCommand("Edit.SelectNone")
          app:doCommand(string.format("EventEdit.Select?FlowID=%d&EventID=%d&EventBlockID=%d", flow.id, ev.id,
            edit.blockIdOf(s, ev.id, parsed)))
          app:doCommand("NoteInput.StartChordSymbolInput")
          app:doCommand("NoteInput.AcceptCurrentChordSymbolTextInput?Definition=D&ChordSymbolEntryAdvanceType=kEndInput")
          app:doCommand("Edit.SelectNone")
          return
        end
      end
    end
  end
  p:check("a piano note at 0", false)
end)
