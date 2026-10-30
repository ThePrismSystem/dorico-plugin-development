-- What Edit.Undo does inside a script, shown by making two kinds of edit and undoing once.
-- What it does: adds a flow by command and a staff text through the object model, runs Edit.Undo once, and prints
-- what each edit looks like before and after.
-- Changes: nothing that stays.
-- Undo: nothing to undo. Don't press Edit > Redo straight afterwards: it would bring the flow and the text back.
-- Builds on: 10-commands.lua and 14-add-notes-rests-text.lua. Open Script > Show Script Console to read what it
-- prints.
--
-- What it shows, and what follows for any script that changes the score:
--   * Everything a script run changes is one undo step, whether it was done by command or through the object model
--     (createNote, createRest, createText, stream:delete, propertyTable:set). Edit > Undo afterwards takes the whole
--     run back. The exception found so far is chord symbols made with the popover's commands, which make undo
--     steps of their own (see the chord-symbols recipe).
--   * Edit.Undo inside a script takes back everything that run has done so far, and nothing from before the run.
--   * After that undo, whatever the run changes next joins the user's last undo step, so Edit > Undo afterwards
--     takes back both. A second Edit.Undo in the run would take back the user's last edit at once. So a script
--     undoes at most once, and changes nothing after it.
--   * A run that changes something and puts it back (a text made and deleted) still leaves an undo step. Edit > Undo
--     straight afterwards uses it up, changing nothing you can see, and a second press reaches your own last edit.

-- helper: guard
-- The app and the open project, or the app and nil when no project is open. The read of app.currentScore goes
-- through pcall in case it raises an error then instead of giving nil, which no run here has checked.
local function guard()
  local app = DoApp.DoApp()
  local ok, score = pcall(function() return app.currentScore end)
  if ok and score then return app, score end
  print("Open a project first, then run this script again.")
  return app, nil
end
-- end helper: guard

local app, score = guard()
if not score then return end
if #score.flows == 0 or #score.flows[1].voiceStreams == 0 then
  print("This needs a flow with a player in it. Add one, then run this script again.")
  return
end

local MARK = "Made by 18-undo.lua"

local function hasMark()
  return app.currentScore.flows[1].voiceStreams[1]:dump():find(MARK, 1, true) ~= nil
end

print("flows at the start: " .. #app.currentScore.flows)
app:doCommand("Project.Flow.New")
print("flows after Project.Flow.New: " .. #app.currentScore.flows)
app.currentScore.flows[1].voiceStreams[1]:createText(DoCore.RhythmicLength(0), DoCore.RhythmicLength(1), MARK)
print("text after createText: " .. (hasMark() and "there" or "missing"))

app:doCommand("Edit.Undo")
print("flows after Edit.Undo: " .. #app.currentScore.flows)
print("text after Edit.Undo: " .. (hasMark() and "still there" or "gone"))
