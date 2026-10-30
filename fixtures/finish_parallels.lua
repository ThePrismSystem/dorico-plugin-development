-- Finishes the imported parallels fixture on its scratch copy: gives the notes parallels.expected.json lists under
-- "userColours" their colours, one by event id (no context) and one through the Properties panel's command (stored
-- for the layout on screen), as a user might. fixtures/build_parallels.py runs it.
local here = debug.getinfo(1, "S").source:match("^@(.*[/\\])")
local repo = here .. "../"
local mine = here .. "?.lua;" .. repo .. "spikes/lib/?.lua;" .. repo .. "lib/?.lua"
for name in pairs(package.loaded) do
  if name:match("^scorereader") or package.searchpath(name, mine) then package.loaded[name] = nil end
end
if not package.path:find(mine, 1, true) then package.path = mine .. ";" .. package.path end
local probe = require("probe")

probe.run("finish_parallels", function(p)
  local json = require("json")
  local savedcopy = require("scorereader.dorico.savedcopy")
  local edit = require("scorereader.dorico.edit")
  local score = require("scorereader.score")
  local values = require("scorereader.values")
  local f = assert(io.open(here .. "parallels.expected.json", "rb"))
  local expected = json.decode(f:read("*a"))
  f:close()
  local app = DoApp.DoApp()
  app:doCommand("NoteInput.Exit")
  app:doCommand("Window.SwitchMode?WindowMode=kWriteMode")
  local s = savedcopy.read(app, { dir = probe.runDir })
  for _, want in ipairs(expected.userColours) do
    local note
    for _, player in ipairs(s.players) do
      if player.name == want.player then
        for _, e in ipairs(score.eventsOf(s, s.flows[1], player)) do
          if e.kind == "note" and values.toNumber(e.position) == want.pos then note = e end
        end
      end
    end
    if p:check(want.player .. " has a note at " .. want.pos, note ~= nil) then
      if want.how == "byId" then
        edit.setProperty(app, note, "kEventColour", want.colour)
      else
        app:doCommand("Edit.SelectNone")
        edit.select(app, note)
        app:doCommand("UI.InvokePropertyChangeValue?Type=kEventColour&Value=" .. want.colour)
        app:doCommand("Edit.SelectNone")
      end
      p:fact(want.player, note.id)
    end
  end
  local after = savedcopy.read(app, { dir = probe.runDir })
  local coloured = 0
  for _, flow in ipairs(after.flows) do
    for _, e in ipairs(flow.events) do
      local colour = e.kind == "note" and score.value(after, e, "kEventColour", after.layouts[1].id)
      if colour then coloured = coloured + 1 end
    end
  end
  p:check("exactly the two notes are coloured", coloured == #expected.userColours, coloured)
end)
