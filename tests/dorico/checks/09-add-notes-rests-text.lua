-- 09-add-notes-rests-text.lua made a third flow with its title, and wrote exactly its notes, rest and text into the
-- flute's voice there, leaving the other flows as they were.
local checks = require("checks")

local NOTES = {
  "C4|0|1", "D4|1|1", "E4|2|1", "F4|3|1", "G4|4|1", "A4|5|1", "B4|6|1", "C5|7|1", "C4|8|2", "E4|8|2", "G4|8|2",
  "D5|11|0.5", "E5|11.5|0.5",
}

return function(p, run)
  local said = 'flow 3, "Written by a script": 13 notes, 1 rest and 1 text for Flute'
  p:check("printed what it wrote", run.printed[1] == said, run.printed[1])
  local score = DoApp.DoApp().currentScore
  p:check("a third flow", #score.flows == 3, #score.flows)
  p:check("its title", checks.flowTitles()[3] == "Written by a script", checks.flowTitles()[3])

  local dump = checks.helper("examples/fundamentals/03-read-notes.lua", { "dump" }, "dump")
  for i, stream in ipairs(score.flows[3].voiceStreams) do
    local notes, rests, texts = {}, {}, {}
    for _, ev in ipairs(dump.parse(stream:dump()).events) do
      if ev.kind == "note" then notes[#notes + 1] = table.concat({ ev.spelling, ev.pos, ev.duration }, "|") end
      if ev.kind == "rest" then rests[#rests + 1] = ev.pos .. "|" .. ev.duration end
      if ev.kind == "text" then texts[#texts + 1] = ev.pos .. "|" .. ev.text end
    end
    if i == 1 then
      p:check("the notes", checks.joined(notes) == checks.joined(NOTES), checks.joined(notes))
      p:check("the rest", checks.joined(rests) == "10|1", checks.joined(rests))
      p:check("the text", checks.joined(texts) == "0|Written by a script", checks.joined(texts))
    else
      p:check("voice " .. i .. " has no notes", #notes == 0, checks.joined(notes))
    end
  end
  checks.musicUnchanged(p)
end
