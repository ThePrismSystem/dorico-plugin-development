-- S1: which notes are selected? Lua has no selection API, so this moves the selection up a semitone, sees which
-- notes' pitches changed in the dumps, and takes the move back with the run's one Edit.Undo. Reports the selected
-- notes and whether every stream's dump is as it was afterwards. Scratch copy only.
local here = debug.getinfo(1, "S").source:match("^@(.*[/\\])")
local mine = here .. "?.lua;" .. here .. "lib/?.lua;" .. here .. "../fixtures/?.lua;" .. here .. "../lib/?.lua"
for name in pairs(package.loaded) do
  if package.searchpath(name, mine) then package.loaded[name] = nil end
end
if not package.path:find(mine, 1, true) then package.path = mine .. ";" .. package.path end
local probe = require("probe")

probe.run("s1_read_selection", function(p)
  local dump = require("scorereader.dorico.dump")
  local app = DoApp.DoApp()
  local function snapshot()
    local out, texts = {}, {}
    for fi, f in ipairs(app.currentScore.flows) do
      for _, s in ipairs(f.voiceStreams) do
        local text = s:dump()
        texts[#texts + 1] = text
        for _, ev in ipairs(dump.parse(text).events) do
          if ev.kind == "note" or ev.kind == "grace" then
            out[ev.id] = { flow = fi, stream = s.id, spelling = ev.spelling, pos = ev.pos }
          end
        end
      end
    end
    return out, table.concat(texts, "\n")
  end
  local before, beforeText = snapshot()
  app:doCommand("NoteEdit.PitchUpChromatic")
  local moved = snapshot()
  app:doCommand("Edit.Undo")
  local _, afterText = snapshot()
  local selected = {}
  for id, n in pairs(before) do
    local m = moved[id]
    if not m or m.spelling ~= n.spelling then
      selected[#selected + 1] = string.format("flow %d stream %d id %d %s at %s -> %s", n.flow, n.stream, id,
        n.spelling, tostring(n.pos), m and m.spelling or "(gone)")
    end
  end
  table.sort(selected)
  p:fact("selected", selected)
  p:check("the music is as it was afterwards", afterText == beforeText)
end)
