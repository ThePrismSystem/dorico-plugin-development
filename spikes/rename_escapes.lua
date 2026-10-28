-- How Dorico reads commas and other characters in a command value. Scratch copy only (the probe confirms it).
-- Renames the flute player (player id 0 in the sample, as its first instrument's id is) and the first flow to each
-- candidate and reads the result back: tostring(player) for the player, the text export for the flow. Last, renames
-- the trumpet player and takes it back with the run's one Edit.Undo, to see what name the undo restores.
local here = debug.getinfo(1, "S").source:match("^@(.*[/\\])")
local mine = here .. "?.lua;" .. here .. "lib/?.lua"
for name in pairs(package.loaded) do
  if package.searchpath(name, mine) then package.loaded[name] = nil end
end
if not package.path:find(mine, 1, true) then package.path = mine .. ";" .. package.path end
local probe = require("probe")

-- What each candidate is sent as, and what a reader would want it to become.
local CANDIDATES = {
  { sent = "A, B", want = "A, B" },
  { sent = "A\\, B", want = "A, B" },
  { sent = "A,B", want = "A,B" },
  { sent = "A \\& B", want = "A & B" },
  { sent = "A\\, B \\& C", want = "A, B & C" },
  { sent = "A\\\\B", want = "A\\B" },
  { sent = '"A, B"', want = "A, B" },
  { sent = "A;B", want = "A;B" },
}

local function flowTitle(app)
  local base = probe.runDir .. "rename-escapes"
  os.remove(base .. ".csv")
  app:doCommand("File.Export.Text?File=" .. base .. ".txt&Show=false")
  local f = assert(io.open(base .. ".csv", "rb"))
  local csv = f:read("*a")
  f:close()
  for line in csv:gmatch("[^\r\n]+") do
    if line:find('"Flow Info (Title)"', 1, true) and line:find(',"1","', 1, true) then
      return line:match('"Flow Info %(Title%)","(.*)","[YN]"$')
    end
  end
end

probe.run("rename_escapes", function(p)
  local app = DoApp.DoApp()
  local flowId = app.currentScore.flows[1].id
  local results = {}
  for _, c in ipairs(CANDIDATES) do
    app:doCommand("Project.Player.Rename?PlayerID=0&Name=" .. c.sent)
    local player = tostring(app.currentScore.players[1])
    app:doCommand(string.format("Project.Flow.Rename?FlowID=%d&Name=%s", flowId, c.sent))
    local flow = flowTitle(app)
    results[#results + 1] = { sent = c.sent, want = c.want, player = player, flow = flow }
  end
  p:fact("results", results)

  app:doCommand("Project.Player.Rename?PlayerID=1&Name=Renamed")
  local renamed = tostring(app.currentScore.players[2])
  app:doCommand("Edit.Undo")
  p:fact("trumpet", { renamed = renamed, afterUndo = tostring(app.currentScore.players[2]),
    flute = tostring(app.currentScore.players[1]) })
end)
