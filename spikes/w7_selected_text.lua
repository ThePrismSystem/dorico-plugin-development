-- Spike W7: which items are selected? Lua can't read a selected text item, so this marks the selection with a
-- property, finds the marked events in a saved copy, and takes the marks off again with the Properties panel's enable
-- switch. On a scratch copy of the reading fixture, it selects the flute's first text and first note itself, as a
-- user would have.
--   python tools/run_lua.py spikes/w7_selected_text.lua --open fixtures/6.2.30/reading.dorico
local here = debug.getinfo(1, "S").source:match("^@(.*[/\\])")
local repo = here .. "../"
local mine = here .. "lib/?.lua;" .. repo .. "lib/?.lua"
for name in pairs(package.loaded) do
  if name:match("^scorereader") or package.searchpath(name, mine) then package.loaded[name] = nil end
end
if not package.path:find(mine, 1, true) then package.path = mine .. ";" .. package.path end
local probe = require("probe")

local MARK = "#ff010203"

probe.run("w7_selected_text", function(p)
  local savedcopy = require("scorereader.dorico.savedcopy")
  local commands = require("scorereader.dorico.commands")
  local score = require("scorereader.score")
  local app = DoApp.DoApp()
  local opts = { dir = probe.runDir }
  app:doCommand("NoteInput.Exit")
  app:doCommand("Window.SwitchMode?WindowMode=kWriteMode")

  local s = savedcopy.read(app, opts)
  local text, note
  for _, e in ipairs(s.flows[1].events) do
    if not text and e.kind == "text" then text = e end
    if not note and e.kind == "note" and e.streamId == s.flows[1].streams[#s.flows[1].streams].id then note = e end
  end
  -- the user's selection: a text and a note (EventEdit.Select replaces, so the note is added by Ctrl-click's command)
  app:doCommand("Edit.SelectNone")
  app:doCommand(commands.select(text.flowId, text.id, text.blockId))
  app:doCommand(commands.build("EventEdit.Select", { { "FlowID", note.flowId }, { "EventID", note.id },
    { "EventBlockID", note.blockId }, { "Add", "true" } }))

  local function marked(read)
    local out = {}
    for _, flow in ipairs(read.flows) do
      for _, e in ipairs(flow.events) do
        for _, x in ipairs(score.entries(read, e)) do
          if x.property == "kEventColour" and x.value:find(MARK:sub(2), 1, true) then
            out[#out + 1] = e.kind .. " " .. e.id .. "@" .. x.layout
          end
        end
      end
    end
    return out
  end

  app:doCommand("UI.InvokePropertyChangeValue?Type=kEventColour&Value=" .. MARK)
  p:fact("selected", { text = text.id, note = note.id })
  p:fact("marked", marked(savedcopy.read(app, opts)))
  app:doCommand("UI.InvokePropertyEnableSwitch?Type=kEventColour&Value=false")
  p:fact("afterUnmark", marked(savedcopy.read(app, opts)))

  -- the text alone, marked by colour and then by kTextHide
  app:doCommand("Edit.SelectNone")
  app:doCommand(commands.select(text.flowId, text.id, text.blockId))
  app:doCommand("UI.InvokePropertyChangeValue?Type=kEventColour&Value=" .. MARK)
  p:fact("textAloneColour", marked(savedcopy.read(app, opts)))
  app:doCommand("UI.InvokePropertyEnableSwitch?Type=kEventColour&Value=false")
  app:doCommand("UI.InvokePropertyChangeValue?Type=kTextHide&Value=true")
  local read = savedcopy.read(app, opts)
  local hidden = {}
  for _, x in ipairs(score.entries(read, read.events[text.id])) do
    hidden[#hidden + 1] = x.property .. "=" .. x.value .. "@" .. x.layout
  end
  p:fact("textAloneHide", hidden)
  app:doCommand("UI.InvokePropertyEnableSwitch?Type=kTextHide&Value=false")
  read = savedcopy.read(app, opts)
  local left = {}
  for _, x in ipairs(score.entries(read, read.events[text.id])) do left[#left + 1] = x.property end
  p:fact("textAfterUnhide", left)

  -- a property of the plug-in's own, which nothing draws
  app:doCommand("UI.InvokePropertyChangeValue?Type=kScoreReaderMark&Value=1")
  read = savedcopy.read(app, opts)
  local own = {}
  for _, x in ipairs(score.entries(read, read.events[text.id])) do own[#own + 1] = x.property .. "=" .. x.value end
  p:fact("ownMark", own)
  app:doCommand("UI.InvokePropertyEnableSwitch?Type=kScoreReaderMark&Value=false")
  read = savedcopy.read(app, opts)
  local gone = {}
  for _, x in ipairs(score.entries(read, read.events[text.id])) do gone[#gone + 1] = x.property end
  p:fact("ownMarkAfter", gone)
  app:doCommand("Edit.SelectNone")
end)
