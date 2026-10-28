-- Which object-model edits does an undo take back? Scratch copy only (the probe confirms it). args.step:
--   "mixed-undo": text A, then Project.Flow.New, then text B, then Edit.Undo inside the run
--   "mixed": text A, Project.Flow.New, text B, and no undo (the driver undoes afterwards)
--   "text-only": text C and nothing else (the driver undoes afterwards)
--   "undo-then-text": Project.Flow.New, Edit.Undo, then text D (the driver undoes afterwards)
--   "text-and-delete": text E made and deleted in the same run
--   "property": a colour set on the trumpet's second note through its property table
--   "user-edit": renames flow 2 by command, standing in for the user's own edit before a run
--   "report": nothing
-- Every step reports which of the texts flow 1's first voice holds, and how many flows there are.
local here = debug.getinfo(1, "S").source:match("^@(.*[/\\])")
local mine = here .. "?.lua;" .. here .. "lib/?.lua"
for name in pairs(package.loaded) do
  if package.searchpath(name, mine) then package.loaded[name] = nil end
end
if not package.path:find(mine, 1, true) then package.path = mine .. ";" .. package.path end
local probe = require("probe")

probe.run("undo_object_edits", function(p)
  local app = DoApp.DoApp()
  local function voice() return app.currentScore.flows[1].voiceStreams[1] end
  local function text(label) voice():createText(DoCore.RhythmicLength(0), DoCore.RhythmicLength(1), "probe " .. label) end
  local step = p.args.step
  if step == "mixed-undo" or step == "mixed" then
    text("A")
    app:doCommand("Project.Flow.New")
    text("B")
    if step == "mixed-undo" then app:doCommand("Edit.Undo") end
  elseif step == "text-only" then
    text("C")
  elseif step == "undo-then-text" then
    app:doCommand("Project.Flow.New")
    app:doCommand("Edit.Undo")
    text("D")
  elseif step == "text-and-delete" then
    local v = voice()
    v:delete(v:createText(DoCore.RhythmicLength(0), DoCore.RhythmicLength(1), "probe E"))
  elseif step == "property" then
    -- the trumpet's voice (the second voice stream) lists its events, having no lyrics or slurs
    local trumpet = app.currentScore.flows[1].voiceStreams[2]
    for _, e in ipairs(trumpet.events) do
      if tostring(e):match("^kNoteEvent") and tostring(e):match(" at 1,") then
        e.propertyTable:set("kEventColour", DoCore.Variant.createString("#ff0000ff"), DoCore.PropertyContext())
      end
    end
  elseif step == "user-edit" then
    app:doCommand(string.format("Project.Flow.Rename?FlowID=%d&Name=Edited", app.currentScore.flows[2].id))
  end
  local base = probe.runDir .. "undo-object-edits"
  os.remove(base .. ".csv")
  app:doCommand("File.Export.Text?File=" .. base .. ".txt&Show=false")
  local f = io.open(base .. ".csv", "rb")
  if f then
    for line in f:read("*a"):gmatch("[^\r\n]+") do
      if line:find('"Flow Info (Title)"', 1, true) and line:find(',"2","', 1, true) then
        p:fact("flow2", line:match('"Flow Info %(Title%)","(.*)","[YN]"$'))
      end
    end
    f:close()
  end
  local dump = voice():dump()
  local has = {}
  for _, label in ipairs({ "A", "B", "C", "D" }) do
    if dump:find("probe " .. label, 1, true) then has[#has + 1] = label end
  end
  p:fact("texts", table.concat(has, " "))
  for _, e in ipairs(app.currentScore.flows[1].voiceStreams[2].events) do
    if tostring(e):match("^kNoteEvent") and tostring(e):match(" at 1,") then
      p:fact("colour", tostring(e.propertyTable:get("kEventColour", DoCore.PropertyContext())))
    end
  end
  p:fact("flows", #app.currentScore.flows)
end)
