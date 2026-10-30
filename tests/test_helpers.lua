-- The examples' helper blocks, loaded out of the examples that teach them, with lines copied from real dumps and
-- text exports of the sample.
local helpers = require("helpers")

local READ_NOTES = "examples/fundamentals/03-read-notes.lua"
local HELLO = "examples/fundamentals/01-hello.lua"
local SAVED_COPY = "examples/fundamentals/04-read-the-saved-copy.lua"
local ROOT = (arg and arg[0] or ""):match("^(.*[/\\])tests[/\\]") or "./"
local COMMANDS = "examples/fundamentals/10-commands.lua"
local SELECTION = "examples/fundamentals/11-act-on-the-selection.lua"
local BY_ID = "examples/fundamentals/12-select-by-id.lua"
local BARS = "examples/fundamentals/09-bars-keys-and-times.lua"
local CHORDS = "examples/recipes/chord-symbols.lua"
local PROOFREAD = "examples/recipes/proofread.lua"

local function parse(lines)
  return helpers.load(READ_NOTES, "dump").parse(table.concat(lines, "\n") .. "\n")
end

local HEADER = '"Path","ID","FlowNumber","FlowName","Instrument","Page","Bar","Type","Text","Hidden"'
local PATH = '"C:/Users/calli/AppData/Local/Temp/dorico-examples-run/scratch.dorico"'

local function records(rows)
  return helpers.load(PROOFREAD, "export").parse(table.concat(rows, "\r\n") .. "\r\n")
end

-- Runs fn with DoApp standing in for Dorico's and print recorded; gives back what was printed.
local function withDorico(app, fn)
  local printed, realPrint, realApp = {}, print, DoApp
  print = function(...) printed[#printed + 1] = table.concat({ ... }, "\t") end
  DoApp = { DoApp = function() return app end }
  local ok, err = pcall(fn)
  print, DoApp = realPrint, realApp
  if not ok then error(err, 2) end
  return printed
end

return {
  dump_reads_notes_rests_and_grace_notes = function(t)
    local ev = parse({
      "Start block id: 1061 position: 0",
      "0 (0) dur: 1: kNoteEvent (id:7932) at 0, duration 1  E5 (ends 1)",
      "0 (0) dur: 1: kRestEvent (id:216) at 0, duration 1  ",
      "8 (8): kGraceNoteEvent (id:200) at 8  secondary pos -1/2 (-0.5), notated duration: 1/2 (0.5), B6 ",
      "1.5 (3/2 (1.5)) dur: 1/2 (0.5): kNoteEvent (id:2884) at 3/2 (1.5), duration 1/2 (0.5)  Eb4 (ends 2)",
      "0 (0): kLyricEvent (id:3) at 0  element ID = 0,  duration 0",
    }).events
    t:eq(#ev, 5)
    t:eq(ev[1].kind, "note")
    t:eq(ev[1].id, 7932)
    t:eq(ev[1].spelling, "E5")
    t:eq(ev[1].pos, 0)
    t:eq(ev[1].duration, 1)
    t:eq(ev[2].kind, "rest")
    t:eq(ev[3].kind, "grace")
    t:eq(ev[3].grace, true)
    t:eq(ev[3].spelling, "B6")
    t:eq(ev[3].pos, 8)
    t:eq(ev[3].duration, nil, "a grace note takes no time")
    t:eq(ev[4].pos, 1.5, "a fraction")
    t:eq(ev[4].duration, 0.5)
    t:eq(ev[4].spelling, "Eb4")
    t:eq(ev[5].kind, "other")
    local notes = helpers.load(READ_NOTES, "dump").notes({ events = ev })
    t:eq(#notes, 3, "notes and grace notes, not the rest or the lyric")
    t:eq(notes[3].spelling, "Eb4")
  end,

  dump_keeps_each_events_instance = function(t)
    local ev = parse({
      "Start block id: 1061 position: 0",
      "0 (0) dur: 1: kNoteEvent (id:7932) at 0, duration 1  E5 (ends 1)",
      "Start block id: 1077 position: 4",
      "4 (4) dur: 2: kNoteEvent (id:7940) at 4, duration 2  G5 (ends 6)",
    }).events
    t:eq(ev[1].instance, 1061)
    t:eq(ev[2].instance, 1077)
  end,

  dump_names_each_voice_stream_by_its_player = function(t)
    local function player(name, ...)
      local ins = {}
      for i, id in ipairs({ ... }) do ins[i] = { id = id } end
      return setmetatable({ instruments = ins }, { __tostring = function() return name end })
    end
    local score = { players = { player("Flute", 5), player("Piano", 9) } }
    local flow = { voiceStreams = { { id = 21 }, { id = 22 }, { id = 23 } }, instruments = { { id = 5 }, { id = 9 },
      { id = 9 } } }
    local owners = helpers.load(READ_NOTES, "dump").owners(score, flow)
    t:eq(owners[21], "Flute")
    t:eq(owners[22], "Piano")
    t:eq(owners[23], "Piano", "a second voice belongs to the same player")
  end,

  csv_reads_quoted_newlines_and_commas = function(t)
    local rec = records({
      HEADER,
      PATH .. ',"0-14-328","1","Sample","Violin, solo & tutti","1","1","Staff-attached text (Default Text)","x","N"',
      PATH .. ',"0-10-326","1","Sample","Flute","1","1","Staff-attached text (Default Text)","two\r\nlines ""quoted""","N"',
    })
    t:eq(#rec, 2)
    t:eq(rec[1].Instrument, "Violin, solo & tutti")
    t:eq(rec[1].ID, "0-14-328")
    t:eq(rec[1].Path, "C:/Users/calli/AppData/Local/Temp/dorico-examples-run/scratch.dorico")
    t:eq(rec[2].Text, 'two\r\nlines "quoted"')
    t:eq(rec[2].Hidden, "N", "the row goes on after the quoted newline")
  end,

  csv_reads_a_missing_column_as_empty = function(t)
    local rec = records({
      '"Path","ID","Instrument","Type","Text"',
      PATH .. ',"","","Flow Info (Title)","Sample"',
      "",
    })
    t:eq(#rec, 1, "a blank line is no record")
    t:eq(rec[1].Text, "Sample")
    t:eq(rec[1].FlowNumber, "", "a column the export left out")
    t:eq(rec[1].Bar, "")
  end,

  csv_skips_a_byte_order_mark = function(t)
    local rec = helpers.load(PROOFREAD, "export").parse("\239\187\191" .. HEADER .. "\n" .. PATH
      .. ',"","","","","","","Project Info (Title)","Sample","N"\n')
    t:eq(rec[1].Path, "C:/Users/calli/AppData/Local/Temp/dorico-examples-run/scratch.dorico")
    t:eq(rec[1].Type, "Project Info (Title)")
  end,

  guard_says_to_open_a_project_when_none_is_open = function(t)
    local guard = helpers.load(HELLO, "guard")
    local app, score
    local printed = withDorico({ currentScore = nil }, function() app, score = guard() end)
    t:eq(score, nil)
    t:ok(app ~= nil, "the app comes back either way")
    t:eq(printed[1], "Open a project first, then run this script again.")
  end,

  guard_treats_an_error_as_no_project = function(t)
    local guard = helpers.load(HELLO, "guard")
    local hub = setmetatable({}, { __index = function() error("No such property: currentScore") end })
    local score
    local printed = withDorico(hub, function() _, score = guard() end)
    t:eq(score, nil)
    t:eq(printed[1], "Open a project first, then run this script again.")
  end,

  commands_escape_backslash_and_ampersand = function(t)
    local commands = helpers.load(COMMANDS, "commands")
    t:eq(commands.value("Handbells (P&F)"), "Handbells (P\\&F)")
    t:eq(commands.value("C:\\Users\\me"), "C:\\\\Users\\\\me")
    t:eq(commands.build("Project.Flow.Rename", { { "FlowID", 3 }, { "Name", "Études & Sketches" } }),
      "Project.Flow.Rename?FlowID=3&Name=Études \\& Sketches")
  end,

  commands_escape_commas = function(t)
    -- spikes/rename_escapes.lua: Dorico ends a value at a bare comma, so "Violin, solo & tutti" became "Violin".
    local commands = helpers.load(COMMANDS, "commands")
    t:eq(commands.value("Violin, solo & tutti"), "Violin\\, solo \\& tutti")
  end,

  commands_refuse_nil = function(t)
    local commands = helpers.load(COMMANDS, "commands")
    t:fails(function() commands.value(nil) end)
    t:fails(function() commands.build("Project.Flow.Rename", { { "FlowID", nil } }) end)
  end,

  commands_keep_equals_signs = function(t)
    local commands = helpers.load(COMMANDS, "commands")
    t:eq(commands.value("A=440"), "A=440")
    t:eq(commands.build("Edit.SelectNone", {}), "Edit.SelectNone", "no parameters, no question mark")
  end,

  midi_reads_sharps_flats_and_octaves = function(t)
    local midi = helpers.load(BY_ID, "midi")
    t:eq(midi("C4"), 60)
    t:eq(midi("A4"), 69)
    t:eq(midi("F#5"), 78)
    t:eq(midi("Eb4"), 63)
    t:eq(midi("Bb2"), 46)
    t:eq(midi("Cb4"), 59, "the octave goes with the letter")
    t:eq(midi("B#3"), 60)
    t:eq(midi("Fx4"), 67, "a double sharp")
    t:eq(midi("Ebb4"), 62, "a double flat")
    t:eq(midi("C-1"), 0)
    t:eq(midi("not a note"), nil)
  end,

  length_makes_fractions_of_a_quarter_note = function(t)
    local length = helpers.load(SELECTION, "length")
    local made = {}
    local realCore = DoCore
    DoCore = { RhythmicLength = function(n, d) made[#made + 1] = n .. "/" .. tostring(d) end }
    local ok, err = pcall(function()
      length(4)
      length(1.5)
      length(7 / 3)
      length(0)
    end)
    DoCore = realCore
    if not ok then error(err, 0) end
    t:eq(made[1], "4/1")
    t:eq(made[2], "3/2", "RhythmicLength(1.5) would give 0 quarters and a half lost")
    t:eq(made[3], "7/3")
    t:eq(made[4], "0/1")
  end,

  names_major_minor_and_seventh_chords = function(t)
    local chords = helpers.load(CHORDS, "chords")
    t:eq(chords.name({ "C3", "C4", "E4", "G4" }), "C")
    t:eq(chords.name({ "A2", "E4", "A4", "C5" }), "Am")
    t:eq(chords.name({ "G2", "B3", "D4", "F4" }), "G7")
    t:eq(chords.name({ "F3", "A3", "C4", "E4" }), "Fmaj7")
    t:eq(chords.name({ "D3", "F3", "A3", "C4" }), "Dm7")
    t:eq(chords.name({ "B3", "D4", "F4" }), "Bdim")
    t:eq(chords.name({ "Bb2", "D4", "F4" }), "Bb", "the root keeps its spelling")
    t:eq(chords.name({ "F#3", "A3", "C#4" }), "F#m")
  end,

  names_inversions_by_their_root = function(t)
    local chords = helpers.load(CHORDS, "chords")
    t:eq(chords.name({ "E3", "G3", "C4" }), "C")
    t:eq(chords.name({ "C4", "E4", "A4" }), "Am")
    t:eq(chords.name({ "F3", "G3", "B3", "D4" }), "G7")
  end,

  refuses_fewer_than_three_pitch_classes = function(t)
    local chords = helpers.load(CHORDS, "chords")
    t:eq(chords.name({ "C3", "C4", "G4" }), nil)
    t:eq(chords.name({ "C4" }), nil)
    t:eq(chords.name({}), nil)
    t:eq(chords.name({ "C4", "D4", "E4" }), nil, "a cluster no template fits")
  end,

  bars_find_a_bar_that_starts_between_quarter_notes = function(t)
    local bars = helpers.load(PROOFREAD, "markedBars")
    -- What the text export would say: the bar at each position, given where bars start.
    local function barOf(starts)
      return function(q)
        local bar = 0
        for i, s in ipairs(starts) do
          if q >= s then bar = i end
        end
        return bar
      end
    end
    local function startOf(pos, bar)
      local at = { [pos] = bar(pos) }
      for _, q in ipairs(bars.coarse(pos)) do at[q] = bar(q) end
      for _, q in ipairs(bars.fine(bars.start(pos, at))) do at[q] = bar(q) end
      return bars.start(pos, at)
    end
    t:eq(startOf(6, barOf({ 0, 4, 8 })), 4, "4/4")
    t:eq(startOf(6, barOf({ 0, 0.5, 4.5, 8.5 })), 4.5, "4/4 after an eighth-note pickup")
    t:eq(startOf(5, barOf({ 0, 1.5, 3, 4.5, 6 })), 4.5, "3/8")
    t:eq(startOf(0, barOf({ 0, 4 })), 0, "the first bar")
  end,

  guard_returns_the_open_project = function(t)
    local guard = helpers.load(HELLO, "guard")
    local project = { flows = {} }
    local app, score
    local printed = withDorico({ currentScore = project }, function() app, score = guard() end)
    t:eq(score, project)
    t:eq(#printed, 0, "nothing printed")
  end,

  reader_helper_finds_lib_in_the_repository_and_beside_the_script = function(t)
    local dir = "C:/plugins/examples/fundamentals/"
    local reader = assert(load(helpers.text(SAVED_COPY, "reader") .. "\nreturn reader", "@" .. dir .. "x.lua"))()
    local before = package.path
    package.loaded["scorereader.fake"] = true
    reader()
    local after = package.path
    package.path = before
    t:eq(after:find(dir .. "../../lib/?.lua;" .. dir .. "lib/?.lua;", 1, true), 1, after)
    t:eq(package.loaded["scorereader.fake"], nil, "an earlier run's module is cleared")
  end,

  bars_from_time_signatures = function(t)
    local starts = helpers.load(BARS, "bars").starts({ { pos = 0, numerator = 4, denominator = 4 },
      { pos = 8, numerator = 3, denominator = 4 } }, 14)
    local got = {}
    for _, b in ipairs(starts) do got[#got + 1] = b.bar .. "@" .. b.pos .. "+" .. b.length end
    t:eq(table.concat(got, " "), "1@0+4 2@4+4 3@8+3 4@11+3")
  end,

  a_time_signature_partway_through_a_bar_cuts_it_short = function(t)
    local starts = helpers.load(BARS, "bars").starts({ { pos = 0, numerator = 4, denominator = 4 },
      { pos = 6, numerator = 2, denominator = 4 } }, 10)
    local got = {}
    for _, b in ipairs(starts) do got[#got + 1] = b.pos .. "+" .. b.length end
    t:eq(table.concat(got, " "), "0+4 4+2 6+2 8+2")
  end,

  an_additive_time_signature_and_a_barline_only_division = function(t)
    local bars = helpers.load(BARS, "bars")
    t:eq(bars.starts({ { pos = 0, numerator = "3+2", denominator = 8 } }, 5)[1].length, 2.5, "3+2/8")
    local starts = bars.starts({ { pos = 0, numerator = 4, denominator = 4 }, { pos = 6 } }, 14)
    local got = {}
    for _, b in ipairs(starts) do got[#got + 1] = b.pos end
    t:eq(table.concat(got, " "), "0 4 6 10", "a barline starts a bar and keeps the signature")
  end,

  a_flow_with_no_time_signature_is_one_bar = function(t)
    local bars = helpers.load(BARS, "bars")
    local starts = bars.starts({}, 10)
    t:eq(#starts, 1)
    t:eq(starts[1].length, 10)
    local bar, beat = bars.at(starts, 7)
    t:eq(bar, 1)
    t:eq(beat, 8)
    t:eq(bars.starts({ { pos = 2, numerator = 4, denominator = 4 } }, 10)[1].length, 2, "music before the first one")
  end,

  bar_and_beat_of_a_position = function(t)
    local bars = helpers.load(BARS, "bars")
    local starts = bars.starts({ { pos = 0, numerator = 4, denominator = 4 },
      { pos = 8, numerator = 3, denominator = 4 } }, 14)
    local bar, beat = bars.at(starts, 9.5)
    t:eq(bar, 3)
    t:eq(beat, 2.5)
    bar, beat = bars.at(starts, 0)
    t:eq(bar .. "/" .. beat, "1/1")
  end,

  a_barline_only_division_at_the_start = function(t)
    local bars = helpers.load(BARS, "bars")
    local starts = bars.starts({ { pos = 0 } }, 8)
    t:eq(#starts, 1, "one bar up to the end")
    t:eq(starts[1].length, 8)
    local bar, beat = bars.at(starts, 3)
    t:eq(bar .. "/" .. beat, "1/4")
  end,

  a_barline_before_the_first_time_signature = function(t)
    local bars = helpers.load(BARS, "bars")
    local starts = bars.starts({ { pos = 2 }, { pos = 6, numerator = 4, denominator = 4 } }, 14)
    local got = {}
    for _, b in ipairs(starts) do got[#got + 1] = b.pos .. "+" .. b.length end
    t:eq(table.concat(got, " "), "0+2 2+4 6+4 10+4")
    local bar, beat = bars.at(starts, 3)
    t:eq(bar .. "/" .. beat, "2/2")
  end,

  a_time_signature_with_no_length_is_one_bar_to_the_next_division = function(t)
    local bars = helpers.load(BARS, "bars")
    for _, numerator in ipairs({ "X", 0 }) do
      local starts = bars.starts({ { pos = 0, numerator = numerator, denominator = 4 },
        { pos = 10, numerator = 4, denominator = 4 } }, 18)
      local got = {}
      for _, b in ipairs(starts) do got[#got + 1] = b.pos .. "+" .. b.length end
      t:eq(table.concat(got, " "), "0+10 10+4 14+4", "numerator " .. tostring(numerator))
    end
  end,

  bars_of_an_empty_flow = function(t)
    local bars = helpers.load(BARS, "bars")
    local starts = bars.starts({}, 0)
    t:eq(#starts, 1)
    local bar, beat = bars.at(starts, 0)
    t:eq(bar .. "/" .. beat, "1/1")
  end,

  read_the_saved_copy_reports_a_save_that_fails = function(t)
    local app = { currentScore = {}, save = function() return false end }
    local printed = withDorico(app, function() dofile(ROOT .. SAVED_COPY) end)
    t:eq(#printed, 1, table.concat(printed, " / "))
    t:eq(printed[1], "The reader couldn't read this project: "
      .. "scorereader: Dorico could not save a copy of the project to read")
  end,
}
