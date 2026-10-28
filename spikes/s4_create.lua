-- S4: which command strings create a chord symbol, a dynamic and a staff text at a selected note? Each try selects
-- one piano note by id, sends its commands, and reports which event kinds appeared anywhere in the flow. Never calls
-- a constructor with guessed arguments. Scratch copy only.
local here = debug.getinfo(1, "S").source:match("^@(.*[/\\])")
local mine = here .. "?.lua;" .. here .. "lib/?.lua;" .. here .. "../fixtures/?.lua"
for name in pairs(package.loaded) do
  if package.searchpath(name, mine) then package.loaded[name] = nil end
end
if not package.path:find(mine, 1, true) then package.path = mine .. ";" .. package.path end
local probe = require("probe")

local TRIES = {
  { label = "chord symbol, as the popover does", pos = 0, commands = { "NoteInput.StartChordSymbolInput",
    "NoteInput.AcceptCurrentChordSymbolTextInput?Definition=C&ChordSymbolEntryAdvanceType=kEndInput" } },
  { label = "chord symbol, accept only", pos = 4, commands = {
    "NoteInput.AcceptCurrentChordSymbolTextInput?Definition=Am&ChordSymbolEntryAdvanceType=kEndInput" } },
  { label = "dynamic, Definition", pos = 8, commands = { "NoteInput.CreateDynamic?Definition=mf" } },
  { label = "dynamic, Dynamic", pos = 12, commands = { "NoteInput.CreateDynamic?Dynamic=ff" } },
  { label = "text, Text", pos = 16, commands = { "NoteInput.CreateText?Text=hello" } },
  { label = "text, Definition", pos = 20, commands = { "NoteInput.CreateText?Definition=hello" } },
  { label = "playing technique", pos = 24, commands = { "NoteInput.CreatePlayingTechnique?Definition=pizz." } },
}

probe.run("s4_create", function(p)
  local dumpparse = require("dumpparse")
  local app = DoApp.DoApp()
  local score = app.currentScore
  local flow = score.flows[1]
  local owners = dumpparse.owners(score, flow)
  local piano
  for _, s in ipairs(flow.voiceStreams) do
    if not piano and owners[s.id] == "Piano" then piano = s end
  end
  local function census()
    local counts = {}
    for _, s in ipairs(app.currentScore.flows[1].allStreams) do
      local d = s:dump()
      for tag in d:gmatch(": (k%a+) %(id:") do counts[tag] = (counts[tag] or 0) + 1 end
    end
    return counts
  end
  app:doCommand("NoteInput.Exit")
  app:doCommand("Window.SwitchMode?WindowMode=kWriteMode")
  local results = {}
  for _, try in ipairs(TRIES) do
    local before = census()
    local parsed = dumpparse.parse(piano:dump())
    local note
    for _, ev in ipairs(parsed.events) do
      if not note and ev.kind == "note" and ev.pos == try.pos then note = ev end
    end
    app:doCommand("Edit.SelectNone")
    app:doCommand(string.format("EventEdit.Select?FlowID=%d&EventID=%d&EventBlockID=%d", flow.id, note.id,
      dumpparse.blockIdOf(piano, note.id, parsed)))
    for _, c in ipairs(try.commands) do app:doCommand(c) end
    app:doCommand("NoteInput.Exit")
    app:doCommand("Edit.SelectNone")
    local after, made = census(), {}
    for tag, n in pairs(after) do
      if n > (before[tag] or 0) then made[#made + 1] = tag .. " +" .. (n - (before[tag] or 0)) end
    end
    results[#results + 1] = try.label .. ": " .. (#made > 0 and table.concat(made, ", ") or "nothing")
  end
  p:fact("results", results)
  local out = assert(io.open(probe.runDir .. "s4-after.txt", "wb"))
  for _, s in ipairs(app.currentScore.flows[1].allStreams) do out:write("--- ", s.id, "\n", s:dump(), "\n") end
  out:close()
end)
