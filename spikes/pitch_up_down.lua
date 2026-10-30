-- Does NoteEdit.PitchDownChromatic after NoteEdit.PitchUpChromatic give every note its exact spelling back? If so,
-- a script can find the selection without an Edit.Undo. With args.octave, the same by octaves
-- (NoteEdit.PitchUpOctave, NoteEdit.PitchDownOctave). Scratch copy only (the probe confirms it). Selects all of each
-- flow in turn (Edit.SelectAll), moves it up and down, and compares every note's spelling with the one before; then
-- puts the music back with the run's one Edit.Undo. The sample's notes are all naturals, so args.spellings can name
-- extra notes to write first, in a new flow (each an exact spelling such as "Fb4").
local here = debug.getinfo(1, "S").source:match("^@(.*[/\\])")
local mine = here .. "?.lua;" .. here .. "lib/?.lua;" .. here .. "../fixtures/?.lua"
for name in pairs(package.loaded) do
  if package.searchpath(name, mine) then package.loaded[name] = nil end
end
if not package.path:find(mine, 1, true) then package.path = mine .. ";" .. package.path end
local probe = require("probe")

probe.run("pitch_up_down", function(p)
  local dumpparse = require("dumpparse")
  local app = DoApp.DoApp()
  app:doCommand("NoteInput.Exit")
  app:doCommand("Window.SwitchMode?WindowMode=kWriteMode")
  if p.args.spellings then
    app:doCommand("Project.Flow.New")
    local flow = app.currentScore.flows[#app.currentScore.flows]
    for i, s in ipairs(p.args.spellings) do
      flow.voiceStreams[1]:createNote(DoCore.RhythmicLength(i - 1), DoCore.RhythmicLength(1),
        DoCore.MIDIPitchWithSpelling.fromString(s))
    end
  end
  local function spellings()
    local out = {}
    for fi, f in ipairs(app.currentScore.flows) do
      for _, s in ipairs(f.voiceStreams) do
        for _, ev in ipairs(dumpparse.parse(s:dump()).events) do
          if ev.spelling then out[#out + 1] = fi .. ":" .. ev.id .. "=" .. ev.spelling end
        end
      end
    end
    return out
  end
  local before = spellings()
  local changed, up = {}, nil
  for _, f in ipairs(app.currentScore.flows) do
    -- select the flow's first note, then everything in the flow
    for _, s in ipairs(f.voiceStreams) do
      local parsed = dumpparse.parse(s:dump())
      local first
      for _, ev in ipairs(parsed.events) do
        if not first and ev.kind == "note" then first = ev.id end
      end
      if first then
        app:doCommand("Edit.SelectNone")
        app:doCommand(string.format("EventEdit.Select?FlowID=%d&EventID=%d&EventBlockID=%d", f.id, first,
          dumpparse.blockIdOf(s, first, parsed)))
        app:doCommand("Edit.SelectAll")
        break
      end
    end
    app:doCommand(p.args.octave and "NoteEdit.PitchUpOctave" or "NoteEdit.PitchUpChromatic")
    up = up or spellings()
    app:doCommand(p.args.octave and "NoteEdit.PitchDownOctave" or "NoteEdit.PitchDownChromatic")
  end
  local after = spellings()
  for i, s in ipairs(before) do
    if after[i] ~= s then changed[#changed + 1] = s .. " -> " .. tostring(after[i]) end
  end
  local moved = 0
  for i, s in ipairs(before) do
    if up[i] ~= s then moved = moved + 1 end
  end
  p:fact("notes", #before)
  p:fact("movedUp", moved)
  p:fact("changedAfterUpAndDown", changed)
  app:doCommand("Edit.SelectNone")
  app:doCommand("Edit.Undo")
  p:check("the undo put everything back", table.concat(spellings(), " ") == table.concat(before, " "))
end)
