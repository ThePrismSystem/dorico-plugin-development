-- Flips a text below the staff before an example runs, as a user would: selects it by id and runs Edit.FlipItem,
-- which stores the flip for the layout on screen. The reading fixture is saved with its full score on screen, and a
-- saved copy read afterwards shows where the flip went. Scratch copy only (the probe confirms it).
--   args.words: the words of the text to flip
local here = debug.getinfo(1, "S").source:match("^@(.*[/\\])")
local repo = here .. "../../"
local mine = here .. "lib/?.lua;" .. repo .. "spikes/lib/?.lua;" .. repo .. "lib/?.lua"
for name in pairs(package.loaded) do
  if package.searchpath(name, mine) then package.loaded[name] = nil end
end
if not package.path:find(mine, 1, true) then package.path = mine .. ";" .. package.path end
local probe = require("probe")

local function textWith(s, words)
  for _, flow in ipairs(s.flows) do
    for _, e in ipairs(flow.events) do
      if e.kind == "text" and e.words == words then return e end
    end
  end
end

probe.run("case_flip", function(p)
  local savedcopy = require("scorereader.dorico.savedcopy")
  local score = require("scorereader.score")
  local edit = require("scorereader.dorico.edit")
  local app = DoApp.DoApp()
  local e = textWith(savedcopy.read(app), p.args.words)
  if not p:check("a text to flip", e ~= nil, p.args.words) then return end
  app:doCommand("NoteInput.Exit")
  app:doCommand("Window.SwitchMode?WindowMode=kWriteMode")
  edit.select(app, e)
  app:doCommand("Edit.FlipItem")
  app:doCommand("Edit.SelectNone")
  local after = savedcopy.read(app)
  local flipped = after.events[e.id]
  p:check("the flip is the full score's", flipped and score.above(after, flipped, score.fullScoreOf(after).id) == false,
    flipped and tostring(score.above(after, flipped, score.fullScoreOf(after).id)))
end, { scratchOnly = true })
