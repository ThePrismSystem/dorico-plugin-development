-- Two questions from the final review, on a scratch copy only (the probe confirms it). args.step picks one:
--   "tuplet": open on spikes/tuplet.musicxml (a triplet of eighths, then a quarter and a half). Reports the flute
--             voice's dump lines, to see how a tuplet's notes give their positions and durations.
--   "unison": on the sample. In a new flow, writes a chord of C4 and C5, selects only the C4 by id, moves it up an
--             octave (onto the C5) and back down, and reports the voice's notes after each step. Takes it all back
--             with the run's one Edit.Undo.
local here = debug.getinfo(1, "S").source:match("^@(.*[/\\])")
local mine = here .. "?.lua;" .. here .. "lib/?.lua;" .. here .. "../fixtures/?.lua"
for name in pairs(package.loaded) do
  if package.searchpath(name, mine) then package.loaded[name] = nil end
end
if not package.path:find(mine, 1, true) then package.path = mine .. ";" .. package.path end
local probe = require("probe")

local function lines(stream, pattern)
  local out = {}
  for line in stream:dump():gmatch("[^\r\n]+") do
    if not pattern or line:find(pattern) then out[#out + 1] = line end
  end
  return out
end

probe.run("tuplet_and_unison", function(p)
  local dumpparse = require("dumpparse")
  local app = DoApp.DoApp()
  if p.args.step == "tuplet" then
    for i, s in ipairs(app.currentScore.flows[1].voiceStreams) do p:fact("voice" .. i, lines(s)) end
    return
  end
  app:doCommand("NoteInput.Exit")
  app:doCommand("Window.SwitchMode?WindowMode=kWriteMode")
  app:doCommand("Project.Flow.New")
  local flow = app.currentScore.flows[#app.currentScore.flows]
  local voice = flow.voiceStreams[1]
  local low = voice:createNote(DoCore.RhythmicLength(0), DoCore.RhythmicLength(1),
    DoCore.MIDIPitchWithSpelling.fromString("C4"))
  voice:createNote(DoCore.RhythmicLength(0), DoCore.RhythmicLength(1), DoCore.MIDIPitchWithSpelling.fromString("C5"))
  local lowId = low.id
  voice = app.currentScore.flows[#app.currentScore.flows].voiceStreams[1]
  local parsed = dumpparse.parse(voice:dump())
  app:doCommand("Edit.SelectNone")
  app:doCommand(string.format("EventEdit.Select?FlowID=%d&EventID=%d&EventBlockID=%d", flow.id, lowId,
    dumpparse.blockIdOf(voice, lowId, parsed)))
  p:fact("before", lines(voice, "Note"))
  app:doCommand("NoteEdit.PitchUpOctave")
  p:fact("afterUp", lines(app.currentScore.flows[#app.currentScore.flows].voiceStreams[1], "Note"))
  app:doCommand("NoteEdit.PitchDownOctave")
  p:fact("afterDown", lines(app.currentScore.flows[#app.currentScore.flows].voiceStreams[1], "Note"))
  app:doCommand("Edit.SelectNone")
  app:doCommand("Edit.Undo")
  p:check("the undo took the flow away", #app.currentScore.flows == 2, #app.currentScore.flows)
end)
