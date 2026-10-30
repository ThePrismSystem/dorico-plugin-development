-- The reader inside Dorico, on a scratch copy of a fixture. Reads the open project through a saved copy, then matches
-- every stream's dump to it and to the fixture file as committed (which an older Dorico may have saved), by event id
-- and position. Last, sets a colour on one note by its ids from the file and reads it back. Args: original (the
-- fixture's path from the repository root) and colour.
local here = debug.getinfo(1, "S").source:match("^@(.*[/\\])")
local repo = here .. "../../"
local mine = here .. "lib/?.lua;" .. repo .. "spikes/lib/?.lua;" .. repo .. "lib/?.lua"
for name in pairs(package.loaded) do
  if name:match("^scorereader") or package.searchpath(name, mine) then package.loaded[name] = nil end
end
if not package.path:find(mine, 1, true) then package.path = mine .. ";" .. package.path end
local probe = require("probe")

probe.run("case_reader", function(p)
  local savedcopy = require("scorereader.dorico.savedcopy")
  local dump = require("scorereader.dorico.dump")
  local match = require("scorereader.dorico.match")
  local edit = require("scorereader.dorico.edit")
  local score = require("scorereader.score")
  local app = DoApp.DoApp()
  local log = {}
  local opts = { dir = probe.runDir, log = function(line) log[#log + 1] = line end }

  local t0 = os.clock()
  local s = savedcopy.read(app, opts)
  p:fact("readSeconds", os.clock() - t0)
  local original = score.readFile(repo .. p.args.original)
  p:fact("fileVersion", original.format.fileVersion)

  local counts, unmatched = { copy = 0, original = 0 }, { copy = {}, original = {} }
  for _, flow in ipairs(app.currentScore.flows) do
    for _, stream in ipairs(flow.allStreams) do
      local parsed = dump.parse(stream:dump())
      for name, read in pairs({ copy = s, original = original }) do
        local m = match.stream(read, flow.id, stream.id, parsed)
        counts[name] = counts[name] + m.count
        for _, why in ipairs(m.unmatched) do
          if #unmatched[name] < 10 then unmatched[name][#unmatched[name] + 1] = "flow " .. flow.id .. ": " .. why end
        end
      end
    end
  end
  p:fact("matched", counts)
  p:check("every event matches the saved copy", #unmatched.copy == 0, table.concat(unmatched.copy, "; "))
  p:check("every event matches the file as committed", #unmatched.original == 0,
    table.concat(unmatched.original, "; "))

  local note
  for _, flow in ipairs(s.flows) do
    for _, e in ipairs(flow.events) do
      if not note and e.kind == "note" then note = e end
    end
  end
  if p:check("the project has a note", note ~= nil) then
    edit.setProperty(app, note, "kEventColour", p.args.colour)
    local after = savedcopy.read(app, opts)
    local got = score.value(after, after.events[note.id], "kEventColour", after.layouts[1].id)
    p:check("a colour set by id reads back", got == p.args.colour, tostring(got))
  end
  p:fact("log", log)
end)
