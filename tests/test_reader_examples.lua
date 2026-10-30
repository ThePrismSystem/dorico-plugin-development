-- The examples that read a saved copy, run in stock Lua on the fixtures, then checked by the check files the in-Dorico
-- suite uses. A stand-in app's save copies the fixture to the path the reader asks for, and its doCommand records each
-- command. 06 is left out: it reads Dorico's own dumps.
local ROOT = (arg and arg[0] or ""):match("^(.*[/\\])tests[/\\]") or "./"
local FIXTURES = ROOT .. "fixtures/6.2.30/"
local SAMPLE, READING = FIXTURES .. "sample.dorico", FIXTURES .. "reading.dorico"
local PICKUP = FIXTURES .. "pickup.dorico"
local PARALLELS = FIXTURES .. "parallels.dorico"
local TMP = (os.getenv("TEMP") or os.getenv("TMPDIR") or "/tmp"):gsub("\\", "/")
local CHECKS = ROOT .. "tests/dorico/lib/?.lua;"

local function copy(src, dst)
  local f = assert(io.open(src, "rb"))
  local bytes = f:read("*a")
  f:close()
  local g = assert(io.open(dst, "wb"))
  g:write(bytes)
  g:close()
  return true
end

-- Runs an example with DoApp and DoCore standing in for Dorico, and puts back what it changed. What it printed, and
-- the commands it sent. currentScore stands in for Lua's flows, which have none unless it is given.
local function run(example, fixture, currentScore)
  local printed, sent = {}, {}
  local app = { currentScore = currentScore or { flows = {} },
    save = function(_, _, path) return copy(fixture, path) end,
    doCommand = function(_, command) sent[#sent + 1] = command end }
  local path, realPrint = package.path, print
  DoApp = { DoApp = function() return app end }
  DoCore = { RhythmicLength = function(num, den) return { num = num, den = den } end }
  print = function(...) printed[#printed + 1] = table.concat({ ... }, "\t") end
  local ok, err = pcall(dofile, ROOT .. example)
  print, DoApp, DoCore, package.path = realPrint, nil, nil, path
  if not ok then error(err, 0) end
  return printed, sent
end

-- Runs a check file on what an example printed; how many checks it made, and the failures.
local function check(name, printed, args)
  local path = package.path
  package.path = CHECKS .. path
  local made, failed = 0, {}
  local p = { check = function(_, label, ok, detail)
    made = made + 1
    if not ok then failed[#failed + 1] = label .. ": " .. tostring(detail) end
    return ok
  end }
  local ok, err = pcall(function()
    assert(loadfile(ROOT .. "tests/dorico/checks/" .. name))()(p, { printed = printed, ok = true }, args)
  end)
  package.path = path
  if not ok then error(err, 0) end
  return made, failed
end

local function passes(t, example, fixture, checkName)
  local made, failed = check(checkName, (run("examples/fundamentals/" .. example, fixture)))
  t:ok(made > 0, checkName .. " made no checks")
  t:eq(#failed, 0, table.concat(failed, " / "))
end

-- Runs a script that asks through the form helper, with text standing in for what the box writes: a "key=value" line
-- per field. The helper takes its Windows route on any system, with TEMP pointing at a temporary folder. Lua 5.2's
-- require doesn't read package.config, so changing it changes only the route.
local function runAnswering(example, fixture, text, currentScore)
  local realConfig, realGetenv, realExecute = package.config, os.getenv, os.execute
  package.config = "\\" .. realConfig:sub(2)
  os.getenv = function(name)
    if name == "TEMP" then return TMP end
    return realGetenv(name)
  end
  os.execute = function(command)
    local f = assert(io.open(command:match('%-Out "([^"]+)"'), "wb"))
    f:write(text)
    f:close()
    return true, "exit", 0
  end
  local ok, printed, sent = pcall(run, example, fixture, currentScore)
  package.config, os.getenv, os.execute = realConfig, realGetenv, realExecute
  if not ok then error(printed, 0) end
  return printed, sent
end

local PARALLELS_ANSWER = "hidden=False\ncontrary=False\ndoublings=False\nouterOnly=False\nrestBreaks=True\n"
  .. "unisons=True\nclear=False\n"

local CAUTIONARY = FIXTURES .. "cautionary.dorico"
local CAUTIONARY_RECIPE = "examples/recipes/cautionary-accidentals.lua"
local CAUTIONARY_ANSWER = "lookBack=4 bars\nbrackets=Round brackets\nrestsCount=True\notherStaves=True\n"
  .. "otherInstruments=False\nremove=False\n"

local TEXTS = FIXTURES .. "texts.dorico"
local FIND_RECIPE = "examples/recipes/find-and-replace.lua"

-- A box's answer: its fields' defaults, {{key, value}}, with changes {[key] = value}.
local function answer(fields, changes)
  local lines = {}
  for i, f in ipairs(fields) do lines[i] = f[1] .. "=" .. (changes[f[1]] or f[2]) end
  return table.concat(lines, "\n") .. "\n"
end

local function findAnswer(changes)
  return answer({ { "mode", "Find" }, { "query", "" }, { "replacement", "" }, { "matchCase", "False" },
    { "wholeWord", "False" }, { "pattern", "False" }, { "flow", "All flows" }, { "player", "All players" },
    { "from", "" }, { "to", "" } }, changes)
end

local NAMES_RECIPE = "examples/recipes/note-names.lua"
local function namesAnswer(changes)
  return answer({ { "system", "English (C, D, E)" }, { "place", "Above the staff" }, { "octave", "False" },
    { "written", "True" }, { "player", "All players" }, { "flow", "All flows" }, { "remove", "False" } }, changes)
end

-- Stands in for Lua's flows, with a voice stream for each of the fixture's. createText adds the words to made and
-- gives the text an id the fixture doesn't have.
local function writableScore(fixture, made)
  local s = require("scorereader.score").readFile(fixture)
  local flows = {}
  for i, flow in ipairs(s.flows) do
    local voices = {}
    for _, stream in ipairs(flow.streams) do
      if stream.type == "voice" then
        voices[#voices + 1] = { id = stream.id, createText = function(_, _, _, words)
          made[#made + 1] = words
          return { id = 100000 + #made }
        end }
      end
    end
    flows[i] = { id = flow.id, voiceStreams = voices, allStreams = voices }
  end
  return { flows = flows }
end

-- Adds a staff text to a voice stream of a score the reader read.
local function addText(s, streamId, pos, words)
  for _, flow in ipairs(s.flows) do
    local stream = flow.streamById[streamId]
    if stream then
      local e = { kind = "text", id = 90000 + #stream.events, words = words, position = { num = pos, den = 1 },
        duration = { num = 0, den = 1 }, streamId = streamId, flowId = flow.id, blockId = 1 }
      table.insert(stream.events, e)
      table.insert(flow.events, e)
      s.events[e.id] = e
      return
    end
  end
  error("no stream " .. streamId)
end
local SOPRANO_FROM_BAR_2 = findAnswer({ mode = "Replace", query = "dolce", replacement = "sweet", wholeWord = "True",
  player = "Soprano", from = "2" })

-- Stands in for the saved copy: the fixture as the reader reads it, after change(s).
local function changedCopy(fixture, change)
  local s = require("scorereader.score").readFile(fixture)
  change(s)
  return function() return { read = function() return s end } end
end

-- Stands in for the score module, with a script's mark, value stored with no layout, added to each note that has the
-- property stored for a layout, as a setting made in the Properties panel is.
local function markedWithTheirOwn(property, value)
  return function(name)
    local real = assert(loadfile(ROOT .. "lib/scorereader/score.lua"))(name)
    local fake = setmetatable({}, { __index = real })
    function fake.entries(s, e)
      local list = real.entries(s, e)
      for _, x in ipairs(list) do
        if x.property == property and x.layout ~= -1 then
          local out = { { property = property, value = value, layout = -1, instance = -1 } }
          for i, y in ipairs(list) do out[i + 1] = y end
          return out
        end
      end
      return list
    end
    return fake
  end
end

return {
  read_the_saved_copy = function(t)
    passes(t, "04-read-the-saved-copy.lua", SAMPLE, "04-read-the-saved-copy.lua")
  end,

  names_and_titles = function(t)
    passes(t, "05-names-and-titles.lua", SAMPLE, "05-names-and-titles.lua")
  end,

  values_per_layout = function(t)
    passes(t, "07-values-per-layout.lua", READING, "07-values-per-layout.lua")
  end,

  text_lyrics_chords_dynamics = function(t)
    passes(t, "08-text-lyrics-chords-dynamics.lua", READING, "08-text-lyrics-chords-dynamics.lua")
  end,

  bars_keys_and_times = function(t)
    passes(t, "09-bars-keys-and-times.lua", READING, "09-bars-keys-and-times.lua")
  end,

  bars_after_a_pickup = function(t)
    passes(t, "09-bars-keys-and-times.lua", PICKUP, "09-bars-keys-and-times.pickup.lua")
  end,

  a_time_signature_outside_the_timebase_stream_makes_no_bar = function(t)
    local score = require("scorereader.score")
    local values = require("scorereader.values")
    local s = score.readFile(READING)
    local flow, stave, fake = s.flows[1], nil, nil
    for _, stream in ipairs(flow.streams) do
      if stream.type == "stave" then stave = stave or stream end
    end
    for _, e in ipairs(flow.events) do
      if e.kind == "timeSignature" then fake = fake or setmetatable({}, { __index = e }) end
    end
    fake.streamId, fake.position, fake.numerator, fake.denominator = stave.id, values.position("2"), 2, 4
    flow.events[#flow.events + 1] = fake
    -- readCopy clears the library's modules but not package.preload, so this stands in for the saved copy.
    package.preload["scorereader.dorico.savedcopy"] = function() return { read = function() return s end } end
    local ok, printed = pcall(run, "examples/fundamentals/09-bars-keys-and-times.lua", READING)
    package.preload["scorereader.dorico.savedcopy"] = nil
    t:ok(ok, tostring(printed))
    local made, failed = check("09-bars-keys-and-times.lua", printed)
    t:ok(made > 0, "no checks")
    t:eq(#failed, 0, table.concat(failed, " / "))
  end,

  set_a_property_by_id_sends_a_command_per_note = function(t)
    local printed, sent = run("examples/fundamentals/13-set-a-property-by-id.lua", SAMPLE)
    t:eq(#sent, 5)
    for _, command in ipairs(sent) do
      t:ok(command:match("^EventEdit%.ChangeProperty%?FlowID=%d+&EventID=%d+&EventBlockID=%d+&Type=kEventColour"
        .. "&Value=#ff1f78b4$"), command)
    end
    -- The stand-in's second copy is the fixture again, so no colour took.
    t:eq(printed[1], "1\tFlute\t4\tG5\tnot coloured")
    t:eq(#printed, 6)
    t:eq(printed[6], "total\t0\t5")
  end,

  chord_symbols_say_which_chords_dorico_didnt_put_in = function(t)
    local printed, sent = run("examples/recipes/chord-symbols.lua", SAMPLE)
    local definitions = {}
    for _, command in ipairs(sent) do
      definitions[#definitions + 1] = command:match("^NoteInput%.AcceptCurrentChordSymbolTextInput%?Definition=(%w+)")
    end
    t:eq(table.concat(definitions, " "), "C Am F G7")
    -- The stand-in's second copy is the fixture again, so none of them went in.
    t:eq(table.concat(printed, " / "), "flow 1, bar 1: C / flow 1, bar 2: Am / flow 1, bar 3: F / flow 1, bar 4: G7"
      .. " / flow 1, bar 1: Dorico put in no chord symbol for C / flow 1, bar 2: Dorico put in no chord symbol for Am"
      .. " / flow 1, bar 3: Dorico put in no chord symbol for F / flow 1, bar 4: Dorico put in no chord symbol for G7")
  end,

  parallel_fifths_finds_and_counts_on_the_fixture = function(t)
    local printed, sent = runAnswering("examples/recipes/parallel-fifths.lua", PARALLELS, PARALLELS_ANSWER)
    t:eq(#printed, 6, table.concat(printed, " / "))
    t:eq(printed[6], "5 found; 19 notes coloured, 1 kept their own colour; 0 old marks taken off.")
    t:eq(#sent, 19, "a command per note coloured")
  end,

  parallel_fifths_leaves_its_mark_on_a_note_with_a_colour_of_its_own = function(t)
    package.preload["scorereader.score"] = markedWithTheirOwn("kEventColour", 'string: "#ffd81b60"')
    local ok, printed, sent = pcall(runAnswering, "examples/recipes/parallel-fifths.lua", PARALLELS,
      (PARALLELS_ANSWER:gsub("clear=False", "clear=True")))
    package.preload["scorereader.score"] = nil
    t:ok(ok, tostring(printed))
    t:eq(table.concat(printed, " / "), "Took this script's colour off 0 notes. / Left it on 1 note that also has a "
      .. "colour of its own, since taking it off could take that colour too.")
    t:eq(#sent, 0, "nothing taken off")
  end,

  cautionary_accidentals_find_and_count_on_the_fixture = function(t)
    local printed, sent = runAnswering(CAUTIONARY_RECIPE, CAUTIONARY, CAUTIONARY_ANSWER)
    t:eq(#printed, 6, table.concat(printed, " / "))
    t:eq(printed[6], "Added 5 cautionary accidentals, kept 0 from an earlier run, took back 0.")
    t:eq(#sent, 5, "a command per accidental")
  end,

  cautionary_accidentals_skip_an_instrument_with_no_key_signature = function(t)
    package.preload["scorereader.dorico.savedcopy"] = changedCopy(CAUTIONARY, function(s)
      s.players[1].instruments[1].entityID = "instrument.brass.horn.f.nokeysig"
    end)
    local ok, printed = pcall(runAnswering, CAUTIONARY_RECIPE, CAUTIONARY, CAUTIONARY_ANSWER)
    package.preload["scorereader.dorico.savedcopy"] = nil
    t:ok(ok, tostring(printed))
    t:eq(printed[1], "Skipped Flute (Flute): it shows no key signature, which this script doesn't handle.")
    t:eq(#printed, 3, "the piano's one finding and the summary")
    t:eq(printed[3], "Added 1 cautionary accidentals, kept 0 from an earlier run, took back 0.")
  end,

  cautionary_accidentals_skip_a_flow_whose_key_or_rule_they_cant_read = function(t)
    package.preload["scorereader.dorico.savedcopy"] = changedCopy(CAUTIONARY, function(s)
      for _, e in ipairs(s.flows[1].events) do
        if e.kind == "keySignature" and e.fifths == -3 then e.fifths = nil end
      end
    end)
    local ok, printed = pcall(runAnswering, CAUTIONARY_RECIPE, CAUTIONARY, CAUTIONARY_ANSWER)
    package.preload["scorereader.dorico.savedcopy"] = changedCopy(CAUTIONARY, function(s)
      s.flows[1].options.accidentals = nil
    end)
    local ok2, printed2 = pcall(runAnswering, CAUTIONARY_RECIPE, CAUTIONARY, CAUTIONARY_ANSWER)
    package.preload["scorereader.dorico.savedcopy"] = nil
    t:ok(ok and ok2, tostring(printed) .. " " .. tostring(printed2))
    local none = "Added 0 cautionary accidentals, kept 0 from an earlier run, took back 0."
    t:eq(table.concat(printed, " / "), "Flow 1 has a key signature this script can't read: skipped. / " .. none)
    t:eq(table.concat(printed2, " / "), "Flow 1 has no accidental rule the reader could find: skipped. / " .. none)
  end,

  cautionary_accidentals_leave_a_mark_on_a_note_with_a_setting_of_its_own = function(t)
    package.preload["scorereader.score"] = markedWithTheirOwn("kNoteAccidentalVisibility_v3",
      'string: "kRoundBrackets"')
    local ok, printed, sent = pcall(runAnswering, CAUTIONARY_RECIPE, CAUTIONARY,
      (CAUTIONARY_ANSWER:gsub("remove=False", "remove=True")))
    local ok2, printed2, sent2 = pcall(runAnswering, CAUTIONARY_RECIPE, CAUTIONARY, CAUTIONARY_ANSWER)
    package.preload["scorereader.score"] = nil
    t:ok(ok and ok2, tostring(printed) .. " " .. tostring(printed2))
    local left = "Left 1 of its accidentals where the note also has a setting of its own, since taking one back could "
      .. "take that setting too."
    t:eq(table.concat(printed, " / "), "Took back 0 cautionary accidentals. / " .. left)
    t:eq(#sent, 0, "nothing taken back")
    t:eq(printed2[#printed2], left, "an ordinary run leaves it too")
    t:eq(#sent2, 5, "and adds the others")
  end,

  find_and_replace_leaves_note_input_before_it_selects = function(t)
    local printed, sent = runAnswering(FIND_RECIPE, TEXTS, findAnswer({ query = "dolce" }))
    t:eq(printed[#printed], "Found 9; the first is selected.")
    t:eq(table.concat(sent, " / ", 1, 3), "NoteInput.Exit / Window.SwitchMode?WindowMode=kWriteMode / Edit.SelectNone")
  end,

  find_and_replace_finding_nothing_changes_nothing = function(t)
    local printed, sent = runAnswering(FIND_RECIPE, TEXTS, findAnswer({ query = "zzz" }))
    t:eq(table.concat(printed, " / "), "Found nothing.")
    t:eq(#sent, 0)
  end,

  find_and_replace_a_replacement_it_cant_work_out_changes_nothing = function(t)
    local printed, sent = runAnswering(FIND_RECIPE, TEXTS,
      findAnswer({ mode = "Replace", query = "dolce", replacement = "%3", pattern = "True" }))
    t:eq(table.concat(printed, " / "),
      "The replacement couldn't be worked out: the pattern has no capture 3. Nothing changed.")
    t:eq(#sent, 0)
  end,

  -- The stand-in app changes nothing, so the copy read afterwards still has the old lyric.
  find_and_replace_checks_each_lyric_it_replaced = function(t)
    local printed = runAnswering(FIND_RECIPE, TEXTS, SOPRANO_FROM_BAR_2)
    t:eq(table.concat(printed, " / "), "lyric\tflow 1\tbar 2, beat 1\tSoprano\tdolce -> sweet: check it, the old "
      .. "one is still there / Replaced 0; left 0 as they were; 1 to check by hand.")
  end,

  find_and_replace_says_when_it_cant_read_the_project_back = function(t)
    local reads = 0
    package.preload["scorereader.dorico.savedcopy"] = function()
      return { read = function()
        reads = reads + 1
        if reads > 1 then error("no copy", 0) end
        return require("scorereader.score").readFile(TEXTS)
      end }
    end
    local ok, printed = pcall(runAnswering, FIND_RECIPE, TEXTS, SOPRANO_FROM_BAR_2)
    package.preload["scorereader.dorico.savedcopy"] = nil
    t:ok(ok, tostring(printed))
    t:eq(table.concat(printed, " / "), "The reader couldn't read this project: no copy / lyric\tflow 1\tbar 2, "
      .. "beat 1\tSoprano\tdolce -> sweet: check it, the project couldn't be read back afterwards / Replaced 0; left 0 "
      .. "as they were; 1 to check by hand.")
  end,

  -- Stream 14 is the flute's, with one note at 0 and none at 7; stream 20 is the piano's, with E5 and G5 at 0.
  note_names_take_off_only_names_with_a_line_per_note_under_them = function(t)
    package.preload["scorereader.dorico.savedcopy"] = changedCopy(READING, function(s)
      addText(s, 14, 0, "C")
      addText(s, 14, 0, "G\nE")
      addText(s, 14, 7, "A")
      addText(s, 20, 0, "G\nE")
    end)
    local ok, printed, sent = pcall(runAnswering, NAMES_RECIPE, READING, namesAnswer({ remove = "True" }))
    package.preload["scorereader.dorico.savedcopy"] = nil
    t:ok(ok, tostring(printed))
    t:eq(table.concat(printed, " / "), "Removed 2 names.")
    local deleted = 0
    for _, command in ipairs(sent) do
      if command == "Edit.Delete" then deleted = deleted + 1 end
    end
    t:eq(deleted, 2)
  end,

  -- Flow 1 changes key at position 16; made atonal, movable do names nothing after it.
  note_names_leave_notes_under_an_atonal_key_unnamed = function(t)
    local all, some = {}, {}
    local printed = runAnswering(NAMES_RECIPE, READING, namesAnswer({}), writableScore(READING, all))
    t:eq(printed[#printed], string.format("Wrote %d names; removed 0 old ones.", #all))
    package.preload["scorereader.dorico.savedcopy"] = changedCopy(READING, function(s)
      for _, e in ipairs(s.flows[1].events) do
        if e.kind == "keySignature" and e.fifths == 1 then e.fifths, e.mode, e.atonal = nil, "atonal", true end
      end
    end)
    local ok, printed2 = pcall(runAnswering, NAMES_RECIPE, READING, namesAnswer({ system = "Movable do" }),
      writableScore(READING, some))
    package.preload["scorereader.dorico.savedcopy"] = nil
    t:ok(ok, tostring(printed2))
    t:ok(#some > 0 and #some < #all, #some .. " of " .. #all)
    t:eq(table.concat(printed2, " / "), string.format("Wrote %d names; removed 0 old ones. / Left %d notes or chords "
      .. "unnamed: Movable do needs a key, and the key signature there is atonal or one this script can't read.",
      #some, #all - #some))
  end,

  -- The stand-in's new texts aren't in the copy read back, so none can be moved below the staff.
  note_names_say_which_names_stayed_above_the_staff = function(t)
    local made = {}
    local printed = runAnswering(NAMES_RECIPE, READING, namesAnswer({ place = "Below the staff" }),
      writableScore(READING, made))
    t:eq(table.concat(printed, " / "), string.format("Wrote %d names; removed 0 old ones. / %d of them stayed above "
      .. "the staff: they weren't in the project read back.", #made, #made))
  end,
}
