-- Spike W5: accidental visibility by event id. On a scratch copy of the reading fixture, sets
-- kNoteAccidentalVisibility_v3 on the violin's notes to each candidate value by EventEdit.ChangeProperty, removes one
-- again two ways, sets one through the Properties panel's route with the full score on screen, and reads every result
-- back from a saved copy. With args.stage = "set" it only sets one value by id and creates a text, for
-- spikes/w5_undo.py to undo from outside; with args.stage = "read" it only reports.
--   python tools/run_lua.py spikes/w5_accidentals.lua --open fixtures/6.2.30/reading.dorico
local here = debug.getinfo(1, "S").source:match("^@(.*[/\\])")
local repo = here .. "../"
local mine = here .. "lib/?.lua;" .. repo .. "lib/?.lua"
for name in pairs(package.loaded) do
  if name:match("^scorereader") or package.searchpath(name, mine) then package.loaded[name] = nil end
end
if not package.path:find(mine, 1, true) then package.path = mine .. ";" .. package.path end
local probe = require("probe")

local VALUES = { "kRoundBrackets", "kSquareBrackets", "kShow", "kHide", "kDefault", "kParenthesise" }
local PROP = "kNoteAccidentalVisibility_v3"

probe.run("w5_accidentals", function(p)
  local savedcopy = require("scorereader.dorico.savedcopy")
  local edit = require("scorereader.dorico.edit")
  local score = require("scorereader.score")
  local app = DoApp.DoApp()
  local opts = { dir = probe.runDir }
  app:doCommand("NoteInput.Exit")
  app:doCommand("Window.SwitchMode?WindowMode=kWriteMode")

  local s = savedcopy.read(app, opts)
  local violin
  for _, pl in ipairs(s.players) do
    if pl.name == "Violin" then violin = pl end
  end
  local notes = {}
  for _, e in ipairs(score.eventsOf(s, s.flows[1], violin)) do
    if e.kind == "note" then notes[#notes + 1] = e end
  end

  local function report(read)
    local out = {}
    for i, n in ipairs(notes) do
      local entries = {}
      for _, x in ipairs(score.entries(read, read.events[n.id])) do
        if x.property:match("^kNoteAccidentalVisibility") then
          entries[#entries + 1] = x.property .. "=" .. x.value .. "@" .. x.layout
        end
      end
      out[i] = n.spelling .. " " .. table.concat(entries, ", ")
    end
    return out
  end

  if p.args.stage == "read" then
    local read = savedcopy.read(app, opts)
    p:fact("accidentals", report(read))
    local texts = 0
    for _, e in ipairs(read.flows[1].events) do
      if e.kind == "text" and e.words == "w5 undo" then texts = texts + 1 end
    end
    p:fact("texts", texts)
    return
  end
  if p.args.stage == "set" then
    edit.setProperty(app, notes[3], PROP, "kRoundBrackets")
    app.currentScore.flows[1].voiceStreams[1]:createText(DoCore.RhythmicLength(0), DoCore.RhythmicLength(0), "w5 undo")
    return
  end

  -- notes 3 to 8: one candidate value each, by id
  for i, v in ipairs(VALUES) do edit.setProperty(app, notes[i + 2], PROP, v) end
  -- note 9: set, then take off with a ChangeProperty that has no Value; note 10: set, then the panel's enable switch
  edit.setProperty(app, notes[9], PROP, "kRoundBrackets")
  app:doCommand(string.format("EventEdit.ChangeProperty?FlowID=%d&EventID=%d&EventBlockID=%d&Type=%s",
    notes[9].flowId, notes[9].id, notes[9].blockId, PROP))
  edit.setProperty(app, notes[10], PROP, "kRoundBrackets")
  edit.select(app, notes[10])
  app:doCommand("UI.InvokePropertyEnableSwitch?Type=" .. PROP .. "&Value=false")
  -- note 11: the Properties panel's route on a selection, full score on screen
  edit.select(app, notes[11])
  app:doCommand("UI.InvokePropertyChangeValue?Type=" .. PROP .. "&Value=kRoundBrackets")
  app:doCommand("Edit.SelectNone")
  p:fact("accidentals", report(savedcopy.read(app, opts)))
end)
