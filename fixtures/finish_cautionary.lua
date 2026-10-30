-- Finishes the imported cautionary fixture on its scratch copy: puts round brackets on the accidental of the note
-- cautionary.expected.json names under "userBracket", through the Properties panel's command with the full score on
-- screen, as a user might. Dorico stores that for the full score's layout. fixtures/build_cautionary.py runs it.
local here = debug.getinfo(1, "S").source:match("^@(.*[/\\])")
local repo = here .. "../"
local mine = here .. "?.lua;" .. repo .. "spikes/lib/?.lua;" .. repo .. "lib/?.lua"
for name in pairs(package.loaded) do
  if name:match("^scorereader") or package.searchpath(name, mine) then package.loaded[name] = nil end
end
if not package.path:find(mine, 1, true) then package.path = mine .. ";" .. package.path end
local probe = require("probe")

local PROPERTY = "kNoteAccidentalVisibility_v3"

probe.run("finish_cautionary", function(p)
  local json = require("json")
  local savedcopy = require("scorereader.dorico.savedcopy")
  local edit = require("scorereader.dorico.edit")
  local score = require("scorereader.score")
  local values = require("scorereader.values")
  local f = assert(io.open(here .. "cautionary.expected.json", "rb"))
  local expected = json.decode(f:read("*a"))
  f:close()
  local app = DoApp.DoApp()
  app:doCommand("NoteInput.Exit")
  app:doCommand("Window.SwitchMode?WindowMode=kWriteMode")
  local s = savedcopy.read(app, { dir = probe.runDir })
  local count = 0
  for _, e in ipairs(s.flows[1].events) do
    if e.kind == "note" then count = count + 1 end
  end
  p:check("every note came in, a tied note as one", count == #expected.notes, count)

  local want = expected.userBracket
  local note
  for _, player in ipairs(s.players) do
    if player.name == want.player then
      for _, e in ipairs(score.eventsOf(s, s.flows[1], player)) do
        if e.kind == "note" and values.toNumber(e.position) == want.pos then note = e end
      end
    end
  end
  if not p:check(want.player .. " has a note at " .. want.pos, note ~= nil) then return end
  app:doCommand("Edit.SelectNone")
  edit.select(app, note)
  app:doCommand("UI.InvokePropertyChangeValue?Type=" .. PROPERTY .. "&Value=" .. want.value)
  app:doCommand("Edit.SelectNone")
  p:fact("note", note.id)

  local after = savedcopy.read(app, { dir = probe.runDir })
  local found = {}
  for _, e in ipairs(after.flows[1].events) do
    if e.kind == "note" then
      for _, x in ipairs(score.entries(after, e)) do
        if x.property == PROPERTY then
          found[#found + 1] = e.id .. " " .. x.layout .. " " .. tostring(values.typed(x.value).value)
        end
      end
    end
  end
  p:check("only that note has an accidental setting, for the full score",
    #found == 1 and found[1] == note.id .. " " .. after.layouts[1].id .. " " .. want.value, table.concat(found, " / "))
end)
