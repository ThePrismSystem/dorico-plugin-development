-- The Dorico layer outside Dorico: command strings, the dump parser, matching, and the saved-copy read with a stand-in
-- for the app. tests/dorico/test_reader.py runs the same layer inside Dorico.
local commands = require("scorereader.dorico.commands")
local edit = require("scorereader.dorico.edit")
local dump = require("scorereader.dorico.dump")
local match = require("scorereader.dorico.match")
local savedcopy = require("scorereader.dorico.savedcopy")
local score = require("scorereader.score")
local values = require("scorereader.values")

local here = debug.getinfo(1, "S").source:match("^@(.*[/\\])") or "./"
local SAMPLE = here .. "../fixtures/6.2.30/sample.dorico"
local READING = here .. "../fixtures/6.2.30/reading.dorico"

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
  removing_a_property_by_id = function(t)
    t:eq(commands.removeProperty(0, 7, 10, "kNoteAccidentalVisibility_v3"),
      "EventEdit.ChangeProperty?FlowID=0&EventID=7&EventBlockID=10&Type=kNoteAccidentalVisibility_v3")
  end,
  edits_send_these_commands = function(t)
    local sent = {}
    local app = { doCommand = function(_, c) sent[#sent + 1] = c end }
    local e = { flowId = 0, id = 7, blockId = 10 }
    edit.delete(app, e)
    edit.removeProperty(app, e, "kEventColour")
    t:eq(table.concat(sent, " | "), "Edit.SelectNone | EventEdit.Select?FlowID=0&EventID=7&EventBlockID=10"
      .. " | Edit.Delete | EventEdit.ChangeProperty?FlowID=0&EventID=7&EventBlockID=10"
      .. "&Type=kEventColour")
  end,
  a_flipped_text_is_below_where_it_was_flipped = function(t)
    local s = score.readFile(here .. "../fixtures/6.2.30/reading.dorico")
    local text
    for _, e in ipairs(s.flows[1].events) do
      if e.kind == "text" and not text then text = e end
    end
    t:eq(score.above(s, text, 0), true, "as the file has it")
    s.cache[text] = { { property = "kTextEventAboveOrBelow", value = 'string: "kBelow"', layout = 0, frameChain = -1,
      instance = -1 } }
    t:eq(score.above(s, text, 0), false, "flipped in the full score")
    t:eq(score.above(s, text, 1), true, "not in a part")
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
  matching_compares_spellings_and_words = function(t)
    local s = score.readFile(READING)
    local flow = s.flows[1]
    local function parsedOf(streamId)
      local parsed = { events = {} }
      for _, e in ipairs(flow.streamById[streamId].events) do
        parsed.events[#parsed.events + 1] = { id = e.id, pos = values.toNumber(e.position), kind = e.kind,
          spelling = e.spelling, text = e.words }
      end
      return parsed
    end
    local function change(parsed, id, field, v)
      for _, ev in ipairs(parsed.events) do
        if ev.id == id then ev[field] = v end
      end
      return parsed
    end
    local note, text
    for _, e in ipairs(flow.events) do
      if not note and e.kind == "note" then note = e end
      if not text and e.kind == "text" then text = e end
    end
    t:eq(#match.stream(s, flow.id, note.streamId, parsedOf(note.streamId)).unmatched, 0)
    local m = match.stream(s, flow.id, note.streamId, change(parsedOf(note.streamId), note.id, "spelling", "Cx4"))
    t:eq(m.unmatched[1], "event " .. note.id .. " is spelled Cx4 in Lua and " .. note.spelling .. " in the file")
    m = match.stream(s, flow.id, text.streamId, change(parsedOf(text.streamId), text.id, "text", "other words"))
    t:eq(m.unmatched[1], "event " .. text.id .. " says \"other words\" in Lua and \"" .. text.words .. "\" in the file")
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
  a_folder_outside_ascii_is_refused_before_saving = function(t)
    local saved = false
    local app = { currentScore = {}, save = function() saved = true return true end }
    local err = errorOf(function() return savedcopy.read(app, { dir = "C:/Users/Zo\235/AppData/Local/Temp/" }) end)
    t:ok(err and err:find("^scorereader: ") and err:find("opts.dir", 1, true), tostring(err))
    t:eq(saved, false, "nothing was saved")
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
  without_a_log_a_copy_that_cannot_be_removed_is_printed = function(t)
    local printed, realPrint = {}, _G.print
    _G.print = function(line) printed[#printed + 1] = line end
    local ok, err = pcall(savedcopy.read, stubApp(readBytes(SAMPLE)), { dir = DIR,
      remove = function() return nil, "in use" end })
    _G.print = realPrint
    os.remove(DIR .. "scorereader-copy.dorico")
    t:ok(ok, tostring(err))
    t:ok(printed[1] and printed[1]:find("could not be deleted: in use", 1, true), tostring(printed[1]))
  end,
}
