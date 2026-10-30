-- The Dorico layer outside Dorico: command strings, the dump parser, matching, and the saved-copy read with a stand-in
-- for the app. tests/dorico/test_reader.py runs the same layer inside Dorico.
local commands = require("scorereader.dorico.commands")
local dump = require("scorereader.dorico.dump")
local match = require("scorereader.dorico.match")
local savedcopy = require("scorereader.dorico.savedcopy")
local score = require("scorereader.score")
local values = require("scorereader.values")

local here = debug.getinfo(1, "S").source:match("^@(.*[/\\])") or "./"
local SAMPLE = here .. "../fixtures/6.2.30/sample.dorico"

local function readBytes(path)
  local f = assert(io.open(path, "rb"))
  local b = f:read("*a")
  f:close()
  return b
end

-- An app whose save writes these bytes (or returns false when bytes is nil); files records reads and removals.
local function stubApp(bytes)
  return { currentScore = {}, save = function(_, _, path)
    if not bytes then return false end
    local f = assert(io.open(path, "wb"))
    f:write(bytes)
    f:close()
    return true
  end }
end

local function errorOf(fn)
  local ok, err = pcall(fn)
  return not ok and tostring(err) or nil
end

local function exists(path)
  local f = io.open(path, "rb")
  if f then f:close() end
  return f ~= nil
end

local DIR = (os.getenv("TEMP") or os.getenv("TMPDIR") or "/tmp"):gsub("\\", "/") .. "/"

return {
  commands_escape_their_values = function(t)
    t:eq(commands.build("Project.Flow.Rename", { { "FlowID", 1 }, { "Name", "A, B & C\\D" } }),
      "Project.Flow.Rename?FlowID=1&Name=A\\, B \\& C\\\\D")
    t:eq(commands.build("Edit.SelectNone"), "Edit.SelectNone")
    t:fails(function() return commands.build("X", { { "Name", nil } }) end, "a missing value")
  end,
  select_and_change_by_id = function(t)
    t:eq(commands.select(0, 7, 10), "EventEdit.Select?FlowID=0&EventID=7&EventBlockID=10")
    t:eq(commands.changeProperty(0, 7, 10, "kNoteAccidentalVisibility_v3", "kRoundBrackets"),
      "EventEdit.ChangeProperty?FlowID=0&EventID=7&EventBlockID=10&Type=kNoteAccidentalVisibility_v3"
      .. "&Value=kRoundBrackets")
  end,
  the_dump_parser = function(t)
    local parsed = dump.parse(table.concat({
      "------------------------------",
      "Start block id: 1014 position: 0",
      "4 (4) dur: 1/3 (0.333333): kNoteEvent (id:276) at 4, duration 1/3 (0.333333)  G5 (ends 13/3 (4.33333))",
      "6 (6): kGraceNoteEvent (id:280) at 6  secondary pos -1/2 (-0.5), notated duration: 1/2 (0.5), E5 ",
      "0 (0): kTextEvent (id:255) at 0 : dolce",
      " (paragraph.defaulttext)",
      "0 (0): kChordSymbolEvent (id:266) at 0  C  0",
    }, "\n"))
    t:eq(#parsed.events, 4)
    t:eq(parsed.events[1].spelling, "G5")
    t:eq(parsed.events[1].instance, 1014)
    t:eq(parsed.events[2].kind, "grace")
    t:eq(parsed.events[2].spelling, "E5")
    t:eq(parsed.events[3].text, "dolce")
    t:eq(parsed.events[4].kind, "other")
    t:eq(#dump.notes(parsed), 2)
  end,
  matching_a_dump_to_the_file = function(t)
    local s = score.readFile(SAMPLE)
    local stream = s.flows[1].streams[#s.flows[1].streams]
    local parsed = { events = {} }
    for _, e in ipairs(stream.events) do
      parsed.events[#parsed.events + 1] = { id = e.id, pos = values.toNumber(e.position), kind = "note" }
    end
    local m = match.stream(s, s.flows[1].id, stream.id, parsed)
    t:eq(#m.unmatched, 0)
    t:eq(m.count, #stream.events)
    parsed.events[#parsed.events + 1] = { id = 99999, pos = 0, kind = "note" }
    parsed.events[1].pos = parsed.events[1].pos + 1
    table.remove(parsed.events, 2)
    m = match.stream(s, s.flows[1].id, stream.id, parsed)
    t:eq(#m.unmatched, 3, "an extra event, a moved one, a missing one: " .. table.concat(m.unmatched, "; "))
  end,
  a_saved_copy_is_read_and_removed = function(t)
    local s = savedcopy.read(stubApp(readBytes(SAMPLE)), { dir = DIR })
    t:eq(s.info.title, "Sample")
    t:eq(exists(DIR .. "scorereader-copy.dorico"), false, "the copy is gone")
  end,
  a_save_that_fails = function(t)
    local err = errorOf(function() return savedcopy.read(stubApp(nil), { dir = DIR }) end)
    t:eq(err, "scorereader: Dorico could not save a copy of the project to read")
  end,
  a_copy_that_cannot_be_read_is_still_removed = function(t)
    local err = errorOf(function() return savedcopy.read(stubApp("not a zip"), { dir = DIR }) end)
    t:ok(err and err:find("^zip: "), tostring(err))
    t:eq(exists(DIR .. "scorereader-copy.dorico"), false, "the copy is gone")
  end,
  a_copy_that_cannot_be_removed_is_logged = function(t)
    local lines = {}
    local s = savedcopy.read(stubApp(readBytes(SAMPLE)), { dir = DIR, log = function(l) lines[#lines + 1] = l end,
      remove = function() return nil, "in use" end })
    os.remove(DIR .. "scorereader-copy.dorico")
    t:ok(s.flows[1], "the read still worked")
    t:ok(lines[#lines]:find("could not be deleted: in use", 1, true), tostring(lines[#lines]))
  end,
}
