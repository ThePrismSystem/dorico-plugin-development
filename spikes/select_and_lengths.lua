-- Three small questions on the sample, scratch copy only (the probe confirms it):
--   what app:doCommand returns;
--   whether a second EventEdit.Select adds to the selection or replaces it (found with the S1 trick);
--   whether DoCore.RhythmicLength takes a fraction of a quarter note, for a text at position 0.5.
local here = debug.getinfo(1, "S").source:match("^@(.*[/\\])")
local mine = here .. "?.lua;" .. here .. "lib/?.lua;" .. here .. "../fixtures/?.lua"
for name in pairs(package.loaded) do
  if package.searchpath(name, mine) then package.loaded[name] = nil end
end
if not package.path:find(mine, 1, true) then package.path = mine .. ";" .. package.path end
local probe = require("probe")

probe.run("select_and_lengths", function(p)
  local dumpparse = require("dumpparse")
  local app = DoApp.DoApp()
  local score = app.currentScore
  local flow = score.flows[1]
  local owners = dumpparse.owners(score, flow)
  local violin
  for _, s in ipairs(flow.voiceStreams) do
    if not violin and owners[s.id] == "Violin, solo & tutti" then violin = s end
  end

  local r1 = app:doCommand("NoteInput.Exit")
  local r2 = app:doCommand("Window.SwitchMode?WindowMode=kWriteMode")
  local r3 = app:doCommand("No.Such.Command")
  p:fact("returns", { exit = type(r1) .. ":" .. tostring(r1), mode = type(r2) .. ":" .. tostring(r2),
    unknown = type(r3) .. ":" .. tostring(r3) })

  local parsed = dumpparse.parse(violin:dump())
  local ids = {}
  for _, ev in ipairs(parsed.events) do
    if ev.kind == "note" and (ev.pos == 0 or ev.pos == 2) then ids[#ids + 1] = ev.id end
  end
  app:doCommand("Edit.SelectNone")
  for _, id in ipairs(ids) do
    app:doCommand(string.format("EventEdit.Select?FlowID=%d&EventID=%d&EventBlockID=%d", flow.id, id,
      dumpparse.blockIdOf(violin, id, parsed)))
  end
  local before = {}
  for _, ev in ipairs(dumpparse.parse(violin:dump()).events) do before[ev.id] = ev.spelling end
  app:doCommand("NoteEdit.PitchUpChromatic")
  local moved = {}
  for _, ev in ipairs(dumpparse.parse(violin:dump()).events) do
    if ev.spelling and before[ev.id] ~= ev.spelling then moved[#moved + 1] = before[ev.id] .. "->" .. ev.spelling end
  end
  app:doCommand("Edit.Undo")
  app:doCommand("Edit.SelectNone")
  p:fact("selectedIds", ids)
  p:fact("moved", moved)

  local function textAt(label, make)
    local okLen, len = pcall(make)
    if not okLen then
      p:fact(label, "error: " .. tostring(len))
      return
    end
    local okText, text = pcall(function() return violin:createText(len, DoCore.RhythmicLength(1), "probe " .. label) end)
    if not okText then
      p:fact(label, "length " .. tostring(len) .. ", createText error: " .. tostring(text))
      return
    end
    for line in violin:dump():gmatch("[^\n]+") do
      if line:find("probe " .. label, 1, true) then p:fact(label, "length " .. tostring(len) .. ", dump: " .. line) end
    end
    violin:delete(text)
  end
  textAt("half", function() return DoCore.RhythmicLength(0.5) end)
  textAt("threeHalves", function() return DoCore.RhythmicLength(3, 2) end)
  textAt("sevenThirds", function() return DoCore.RhythmicLength(7, 3) end)
end)
