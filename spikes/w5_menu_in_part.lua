-- Spike W5, a part on screen: which layout Edit.ShowAccidentalInBrackets stores with a part on screen. Run by
-- spikes/w5_menu_in_part.py on a scratch copy of the reading fixture. With args.stage = "find" it reports the flute's
-- part layout and a flute note with no accidental visibility of its own; with args.stage = "set" (the part on screen)
-- it puts that note's accidental in brackets by the menu command and reads the stored layout back from a saved copy.
local here = debug.getinfo(1, "S").source:match("^@(.*[/\\])")
local repo = here .. "../"
local mine = here .. "lib/?.lua;" .. repo .. "lib/?.lua"
for name in pairs(package.loaded) do
  if name:match("^scorereader") or package.searchpath(name, mine) then package.loaded[name] = nil end
end
if not package.path:find(mine, 1, true) then package.path = mine .. ";" .. package.path end
local probe = require("probe")

local PROP = "kNoteAccidentalVisibility_v3"

probe.run("w5_menu_in_part", function(p)
  local savedcopy = require("scorereader.dorico.savedcopy")
  local edit = require("scorereader.dorico.edit")
  local score = require("scorereader.score")
  local app = DoApp.DoApp()
  local opts = { dir = probe.runDir }
  local s = savedcopy.read(app, opts)

  local function entriesOf(e)
    local out = {}
    for _, x in ipairs(score.entries(s, e)) do
      if x.property == PROP then out[#out + 1] = { layout = x.layout, value = x.value } end
    end
    return out
  end

  if p.args.stage == "find" then
    local flute = s.players[1]
    for _, e in ipairs(score.eventsOf(s, s.flows[1], flute)) do
      if e.kind == "note" and #entriesOf(e) == 0 then
        p:fact("note", { flowId = e.flowId, eventId = e.id, blockId = e.blockId, spelling = e.spelling })
        break
      end
    end
    p:fact("partLayoutId", score.partOf(s, flute).id)
    p:fact("fullScoreId", s.layouts[1].id)
    p:fact("path", probe.projectPath(app))
    p:check("found a note", p.facts.note ~= nil)
    return
  end

  local e = s.events[p.args.eventId]
  app:doCommand("Edit.SelectNone")
  edit.select(app, e)
  app:doCommand("Edit.ShowAccidentalInBrackets")
  app:doCommand("Edit.SelectNone")
  s = savedcopy.read(app, opts)
  local stored = entriesOf(s.events[e.id])
  p:fact("stored", stored)
  p:check("the command stored something", #stored > 0)
end)
