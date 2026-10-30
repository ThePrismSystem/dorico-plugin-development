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
local ASK = "examples/fundamentals/17-ask-and-report.lua"
local TMP = (os.getenv("TEMP") or os.getenv("TMPDIR") or "/tmp"):gsub("\\", "/")
local LAYOUTS = "examples/fundamentals/07-values-per-layout.lua"
local CHORDS = "examples/recipes/chord-symbols.lua"
local PROOFREAD = "examples/recipes/proofread.lua"
local EXPORT = "examples/fundamentals/15-layout-and-notation-options.lua"

local function parse(lines)
  return helpers.load(READ_NOTES, "dump").parse(table.concat(lines, "\n") .. "\n")
end

local HEADER = '"Path","ID","FlowNumber","FlowName","Instrument","Page","Bar","Type","Text","Hidden"'
local PATH = '"C:/Users/calli/AppData/Local/Temp/dorico-examples-run/scratch.dorico"'

local function records(rows)
  return helpers.load(EXPORT, "export").parse(table.concat(rows, "\r\n") .. "\r\n")
end

-- Where each bar from the bars helper starts and how long it is, as "<pos>+<length>".
local function spans(starts)
  local out = {}
  for _, b in ipairs(starts) do out[#out + 1] = b.pos .. "+" .. b.length end
  return table.concat(out, " ")
end

-- The same with each bar's number, as "<bar>@<pos>+<length>".
local function brief(starts)
  local out = {}
  for _, b in ipairs(starts) do out[#out + 1] = b.bar .. "@" .. b.pos .. "+" .. b.length end
  return table.concat(out, " ")
end

local function writeFile(path, text)
  local f = assert(io.open(path, "wb"))
  f:write(text)
  f:close()
end

local function readFile(path)
  local f = io.open(path, "rb")
  if not f then return nil end
  local text = f:read("*a")
  f:close()
  return text
end

-- An os.execute for the form's Windows route that writes this answer where the box would.
local function answering(text)
  return function(command)
    writeFile(command:match('%-Out "([^"]+)"'), text)
    return true, "exit", 0
  end
end

-- An io.popen for the form's Mac route: each call gives the next output and records its command in sent.
local function popening(outputs, sent)
  return function(command)
    sent[#sent + 1] = command
    local text = outputs[#sent]
    return { read = function() return text end, close = function() return true end }
  end
end

-- Parses a form script with PowerShell's own parser and writes the number of parse errors and the box's title.
local PARSE_TITLE = [[
param([string]$Path, [string]$Out)
$tokens = $null; $errors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$errors)
$title = $ast.Find({ param($a) $a -is [System.Management.Automation.Language.AssignmentStatementAst] -and
  $a.Left.Extent.Text -eq '$form.Text' }, $true)
$text = "$($errors.Count)" + [char]10 + $title.Right.Expression.Value
[System.IO.File]::WriteAllText($Out, $text, (New-Object System.Text.UTF8Encoding $false))
]]

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
    local rec = helpers.load(EXPORT, "export").parse("\239\187\191" .. HEADER .. "\n" .. PATH
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

  names_one_chord_a_bar_where_it_changes = function(t)
    local bars, barchords = helpers.load(CHORDS, "bars"), helpers.load(CHORDS, "barchords")
    local chords = helpers.load(CHORDS, "chords")
    local starts = bars.starts({ { pos = 0, numerator = 4, denominator = 4 } }, 16)
    local function n(pos, duration, spelling) return { pos = pos, duration = duration, spelling = spelling } end
    local function brief(list)
      local out = {}
      for i, c in ipairs(list) do out[i] = c.bar .. ":" .. c.name .. "@" .. c.pos end
      return table.concat(out, " ")
    end
    -- C broken over bar 1; A minor with a passing B in bar 2, so only its first beat names it; A minor again in bar 3;
    -- G7 from beat 2 of bar 4
    local notes = { n(0, 1, "C4"), n(1, 1, "E4"), n(2, 2, "G4"),
      n(4, 4, "A3"), n(4, 2, "C4"), n(4, 2, "E4"), n(6, 1, "B4"),
      n(8, 4, "A3"), n(8, 4, "C4"), n(8, 4, "E4"),
      n(13, 3, "G3"), n(13, 3, "B3"), n(13, 3, "D4"), n(13, 3, "F4") }
    t:eq(brief(barchords.of(notes, starts, chords.name)), "1:C@0 2:Am@4 4:G7@13")
    local tied = { n(0, 8, "C4"), n(0, 8, "E4"), n(0, 8, "G4"), n(8, 4, "F4"), n(8, 4, "A4"), n(8, 4, "C5") }
    t:eq(brief(barchords.of(tied, starts, chords.name)), "1:C@0 3:F@8", "a chord tied into bar 2 isn't new there")
    t:eq(brief(barchords.of({ n(0, 4, "C4"), n(0, 4, "G4") }, starts, chords.name)), "", "two pitch classes")
    -- C, then F struck on beat 3 and held through bar 2, where no note starts, then F struck again in bar 3
    local held = { n(0, 2, "C4"), n(0, 2, "E4"), n(0, 2, "G4"), n(2, 6, "F4"), n(2, 6, "A4"), n(2, 6, "C5"),
      n(8, 4, "F4"), n(8, 4, "A4"), n(8, 4, "C5"), n(12, 4, "G3"), n(12, 4, "B3"), n(12, 4, "D4"), n(12, 4, "F4") }
    t:eq(brief(barchords.of(held, starts, chords.name)), "1:C@0 3:F@8 4:G7@12",
      "a chord reached by held notes goes in at the next bar where a note starts")
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

  out_of_range_against_the_instruments_own_ranges = function(t)
    local outofrange, midi = helpers.load(PROOFREAD, "outofrange"), helpers.load(BY_ID, "midi")
    local flute = { standard = "C4-A6", advanced = "B3-D7" }
    local function brief(pitch, range)
      local out = outofrange.check(pitch, range, midi)
      return out and table.concat({ out.side, out.which, out.from, out.to }, " ") or "in range"
    end
    t:eq(brief(57, flute), "below advanced B3 D7", "A3 is past even the advanced range")
    t:eq(brief(59, flute), "below standard C4 A6", "B3 is past only the standard range")
    t:eq(brief(60, flute), "in range")
    t:eq(brief(93, flute), "in range", "A6, the top of the standard range")
    t:eq(brief(95, flute), "above standard C4 A6")
    t:eq(brief(99, flute), "above advanced B3 D7")
    local bassoon = { standard = "A#1-A4", advanced = "A1-E5" }
    t:eq(brief(33, bassoon), "below standard A#1 A4", "A1, under a range that starts on a sharp")
    t:eq(brief(32, bassoon), "below advanced A1 E5")
    t:eq(brief(10, { standard = "A0-C8" }), "below standard A0 C8", "only a standard range")
    t:eq(brief(10, {}), "in range", "no range, as for unpitched percussion")
    t:eq(brief(10, nil), "in range")
  end,

  guard_returns_the_open_project = function(t)
    local guard = helpers.load(HELLO, "guard")
    local project = { flows = {} }
    local app, score
    local printed = withDorico({ currentScore = project }, function() app, score = guard() end)
    t:eq(score, project)
    t:eq(#printed, 0, "nothing printed")
  end,

  read_copy_puts_its_lib_folders_first_once = function(t)
    local dir = "C:/plugins/examples/fundamentals/"
    local mine = dir .. "../../lib/?.lua;" .. dir .. "lib/?.lua;"
    local other = "C:/other/lib/?.lua;"
    local readCopy = assert(load(helpers.text(SAVED_COPY, "readCopy") .. "\nreturn readCopy", "@" .. dir .. "x.lua"))()
    local before = package.path
    package.path = other .. mine .. before
    package.loaded["scorereader.fake"] = true
    local printed = withDorico({}, function() readCopy({ currentScore = {}, save = function() return false end }) end)
    local after = package.path
    package.path = before
    t:eq(after:sub(1, #mine + #other), mine .. other, "ahead of another copy of the library")
    t:eq(select(2, after:gsub("C:/plugins/", "")), 2, "each folder once")
    t:eq(package.loaded["scorereader.fake"], nil, "an earlier run's module is cleared")
    t:eq(printed[1], "The reader couldn't read this project: "
      .. "scorereader: Dorico could not save a copy of the project to read")
  end,

  bars_from_time_signatures = function(t)
    local starts = helpers.load(BARS, "bars").starts({ { pos = 0, numerator = 4, denominator = 4 },
      { pos = 8, numerator = 3, denominator = 4 } }, 14)
    t:eq(brief(starts), "1@0+4 2@4+4 3@8+3 4@11+3")
  end,

  a_time_signature_partway_through_a_bar_cuts_it_short = function(t)
    local starts = helpers.load(BARS, "bars").starts({ { pos = 0, numerator = 4, denominator = 4 },
      { pos = 6, numerator = 2, denominator = 4 } }, 10)
    t:eq(spans(starts), "0+4 4+2 6+2 8+2")
  end,

  an_additive_time_signature_and_a_barline_only_division = function(t)
    local bars = helpers.load(BARS, "bars")
    t:eq(bars.starts({ { pos = 0, numerator = "3+2", denominator = 8 } }, 5)[1].length, 2.5, "3+2/8")
    t:eq(spans(bars.starts({ { pos = 0, numerator = 4, denominator = 4 }, { pos = 6 } }, 14)), "0+4 4+2 6+4 10+4",
      "a barline starts a bar and keeps the signature")
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
    t:eq(spans(starts), "0+2 2+4 6+4 10+4")
    local bar, beat = bars.at(starts, 3)
    t:eq(bar .. "/" .. beat, "2/2")
  end,

  a_time_signature_with_no_length_is_one_bar_to_the_next_division = function(t)
    local bars = helpers.load(BARS, "bars")
    for _, numerator in ipairs({ "X", 0 }) do
      local starts = bars.starts({ { pos = 0, numerator = numerator, denominator = 4 },
        { pos = 10, numerator = 4, denominator = 4 } }, 18)
      t:eq(spans(starts), "0+10 10+4 14+4", "numerator " .. tostring(numerator))
    end
  end,

  bars_after_a_pickup = function(t)
    local bars = helpers.load(BARS, "bars")
    local starts = bars.starts({ { pos = 0, numerator = 4, denominator = 4, pickup = 1 } }, 9)
    t:eq(brief(starts), "0@0+1 1@1+4 2@5+4", "the pickup is bar 0")
    local bar, beat = bars.at(starts, 0)
    t:eq(bar .. "/" .. beat, "0/4", "a one-beat pickup is on beat 4")
    bar, beat = bars.at(starts, 1)
    t:eq(bar .. "/" .. beat, "1/1")
  end,

  a_pickup_of_nothing_leaves_the_first_bar_bar_1 = function(t)
    local starts = helpers.load(BARS, "bars").starts({ { pos = 0, numerator = 4, denominator = 4, pickup = 0 } }, 8)
    t:eq(brief(starts), "1@0+4 2@4+4")
  end,

  bars_of_a_flow_start_with_its_pickup = function(t)
    local values = require("scorereader.values")
    local s = require("scorereader.score").readFile(ROOT .. "fixtures/6.2.30/pickup.dorico")
    local barsOf = helpers.load(PROOFREAD, "barsOf", { bars = helpers.load(BARS, "bars"), values = values })
    t:eq(brief(barsOf(s.flows[1])):match("^%S+ %S+"), "0@0+1 1@1+4", "a one-beat pickup in 4/4")
  end,

  bars_of_a_flow_leave_out_a_time_signature_outside_the_timebase_stream = function(t)
    local values = require("scorereader.values")
    local barsOf = helpers.load(PROOFREAD, "barsOf", { bars = helpers.load(BARS, "bars"), values = values })
    local zero = values.position("0")
    local flow = { streamById = { [1] = { type = "timebase" }, [2] = { type = "stave" }, [3] = { type = "voice" } },
      events = {
        { kind = "timeSignature", streamId = 1, position = zero, duration = zero, numerator = 4, denominator = 4 },
        { kind = "timeSignature", streamId = 2, position = values.position("2"), duration = zero, numerator = 2,
          denominator = 4 },
        { kind = "note", streamId = 3, position = zero, duration = values.position("8") },
      } }
    t:eq(brief(barsOf(flow)), "1@0+4 2@4+4")
  end,

  a_short_first_bar_after_a_later_time_signature = function(t)
    local bars = helpers.load(BARS, "bars")
    local starts = bars.starts({ { pos = 0, numerator = 4, denominator = 4 },
      { pos = 8, numerator = 3, denominator = 4, pickup = 2 } }, 15)
    t:eq(brief(starts), "1@0+4 2@4+4 3@8+2 4@10+3 5@13+2")
    local bar, beat = bars.at(starts, 9)
    t:eq(bar .. "/" .. beat, "3/3", "the short bar's notes count from its end")
  end,

  bars_of_an_empty_flow = function(t)
    local bars = helpers.load(BARS, "bars")
    local starts = bars.starts({}, 0)
    t:eq(#starts, 1)
    local bar, beat = bars.at(starts, 0)
    t:eq(bar .. "/" .. beat, "1/1")
  end,

  where_names_an_entry_s_context = function(t)
    local where = helpers.load(LAYOUTS, "where")
    local names = { [0] = "Full score", [5] = "Flute" }
    t:eq(where({ layout = -1, instance = -1, frameChain = -1 }, names), "every layout")
    t:eq(where({ layout = 0, instance = -1, frameChain = -1, offset = "" }, names), "layout Full score")
    t:eq(where({ layout = -1, instance = 1014, frameChain = -1, offset = "0:0:1:0" }, names),
      "every layout, block instance 1014", "an offset of 0 is the note's start")
    t:eq(where({ layout = 5, instance = 12, frameChain = 3, staveType = "kCondensed", offset = "0:1:2:0" }, names),
      "layout Flute, block instance 12, frame chain 3, condensed staves, 1/2 quarter notes into the note")
    t:eq(where({ layout = 9, instance = -1, frameChain = -1, staveType = "kNormal" }, names), "layout 9",
      "a layout with no name, on normal staves")
  end,

  read_the_saved_copy_reports_a_save_that_fails = function(t)
    local app = { currentScore = {}, save = function() return false end }
    local printed = withDorico(app, function() dofile(ROOT .. SAVED_COPY) end)
    t:eq(#printed, 1, table.concat(printed, " / "))
    t:eq(printed[1], "The reader couldn't read this project: "
      .. "scorereader: Dorico could not save a copy of the project to read")
  end,

  form_script_quotes_titles_labels_and_defaults = function(t)
    local form = helpers.load(ASK, "form")
    local script = form.script("Zoë's box", {
      { key = "words", label = "Words & more", kind = "text", default = "it's" },
      { key = "loud", label = "Loud", kind = "check", default = true },
      { key = "which", label = "Which", kind = "choice", default = "b", choices = { "a", "b'c" } },
    })
    t:ok(script:find("$form.Text = 'Zoë''s box'", 1, true), "the title")
    t:ok(script:find("$label.Text = 'Words & more'", 1, true), "a label keeps its ampersand")
    t:ok(script:find("$c.Text = 'it''s'", 1, true), "a text default")
    t:ok(script:find("$c.Checked = $true", 1, true), "a ticked box")
    t:ok(script:find("[void]$c.Items.AddRange(@('a', 'b''c'))", 1, true), "the choices")
    t:ok(script:find("$c.SelectedItem = 'b'", 1, true), "the chosen one")
  end,

  form_parse_reads_each_kind = function(t)
    local form = helpers.load(ASK, "form")
    local fields = { { key = "words", kind = "text" }, { key = "loud", kind = "check" },
      { key = "which", kind = "choice" } }
    local answers = form.parse("words=a=b\r\nloud=True\nwhich=b'c\n", fields)
    t:eq(answers.words, "a=b")
    t:eq(answers.loud, true)
    t:eq(answers.which, "b'c")
    answers = form.parse("words=\nloud=False\nwhich=a\n", fields)
    t:eq(answers.loud, false)
    t:eq(answers.words, "", "an empty text is an answer")
  end,

  form_parse_of_no_answer_is_cancel = function(t)
    local form = helpers.load(ASK, "form")
    local fields = { { key = "words", kind = "text" } }
    t:eq(form.parse(nil, fields), nil)
    t:eq(form.parse("", fields), nil)
    t:eq(form.parse("other=x\n", fields), nil, "an answer missing a field")
  end,

  form_on_windows_runs_the_box_and_reads_its_answer = function(t)
    local form = helpers.load(ASK, "form")
    local fields = { { key = "words", label = "Words", kind = "text", default = "" } }
    local realExecute, ran, head = os.execute, nil, nil
    os.execute = function(command)
      ran = command
      local script = assert(io.open(command:match('%-File "([^"]+)"'), "rb"))
      head = script:read(3)
      script:close()
      local f = assert(io.open(command:match('%-Out "([^"]+)"'), "wb"))
      f:write("words=hello\n")
      f:close()
      return true, "exit", 0
    end
    local ok, answers = pcall(form.windows, "Box", fields, TMP)
    os.execute = answering("")
    local ok2, cancelled, why = pcall(form.windows, "Box", fields, TMP)
    os.execute = realExecute
    t:ok(ok, tostring(answers))
    t:ok(ran and ran:find("^powershell %-NoProfile"), tostring(ran))
    t:eq(answers and answers.words, "hello")
    t:eq(head, "\239\187\191", "the script starts with a UTF-8 byte order mark, so PowerShell 5.1 reads it as UTF-8")
    t:ok(ok2, tostring(cancelled))
    t:eq(cancelled, nil, "Cancel writes an empty answer")
    t:eq(why, nil, "Cancel isn't a failure")
  end,

  form_script_doubles_curly_single_quotes = function(t)
    local form = helpers.load(ASK, "form")
    local script = form.script("WE\226\128\153LL \226\128\152x\226\128\154y\226\128\155",
      { { key = "k", label = "L", kind = "text" } })
    t:ok(script:find("$form.Text = 'WE\226\128\153\226\128\153LL \226\128\152\226\128\152x"
      .. "\226\128\154\226\128\154y\226\128\155\226\128\155'", 1, true), "every curly single quote doubled")
  end,

  form_script_parses_to_the_title_it_was_given = function(t)
    -- Only Windows has PowerShell to parse the script with. The parser reads it without running anything.
    if package.config:sub(1, 1) ~= "\\" then return end
    local form = helpers.load(ASK, "form")
    local title = "x\226\128\153; Write-Output INJECTED; \226\128\152"
    local script, parse, out = TMP .. "/form-test-box.ps1", TMP .. "/form-test-parse.ps1", TMP .. "/form-test-parse.txt"
    writeFile(script, "\239\187\191" .. form.script(title,
      { { key = "k", label = "WE\226\128\153LL GATHER LILACS", kind = "text" } }))
    writeFile(parse, PARSE_TITLE)
    os.remove(out)
    os.execute('powershell -NoProfile -ExecutionPolicy Bypass -File "' .. parse .. '" -Path "' .. script
      .. '" -Out "' .. out .. '"')
    local text = readFile(out)
    os.remove(script)
    os.remove(parse)
    os.remove(out)
    t:eq(text, "0\n" .. title, "no parse errors, and the title is the whole string")
  end,

  form_on_windows_says_why_when_powershell_gives_no_answer = function(t)
    local form = helpers.load(ASK, "form")
    local fields = { { key = "words", label = "Words", kind = "text", default = "" } }
    local realExecute = os.execute
    os.execute = function() return nil, "exit", 1 end
    local ok, answers, why = pcall(form.windows, "Box", fields, TMP)
    os.execute = answering("other=x\n")
    local ok2, partial, why2 = pcall(form.windows, "Box", fields, TMP)
    os.execute = realExecute
    t:ok(ok and ok2, tostring(answers) .. " " .. tostring(partial))
    t:eq(answers, nil)
    t:eq(why, "PowerShell gave no answer")
    t:eq(partial, nil)
    t:eq(why2, "the box's answer left out words")
  end,

  form_on_windows_says_why_when_it_cant_write_the_script = function(t)
    local form = helpers.load(ASK, "form")
    local folder = TMP .. "/no-such-folder-" .. os.time()
    local answers, why = form.windows("Box", { { key = "k", label = "K", kind = "text" } }, folder)
    t:eq(answers, nil)
    t:eq(why, "couldn't write " .. folder .. "/dorico-form.ps1")
  end,

  form_ask_on_windows_says_why_when_there_is_no_temporary_folder = function(t)
    local form = helpers.load(ASK, "form")
    local realConfig, realGetenv = package.config, os.getenv
    package.config = "\\" .. realConfig:sub(2)
    os.getenv = function() return nil end
    local ok, answers, why = pcall(form.ask, "Box", { { key = "k", label = "K", kind = "text" } })
    package.config, os.getenv = realConfig, realGetenv
    t:ok(ok, tostring(answers))
    t:eq(answers, nil)
    t:eq(why, "neither TEMP nor TMP names a folder")
  end,

  form_on_a_mac_reads_each_answer_and_quotes_what_it_sends = function(t)
    local form = helpers.load(ASK, "form")
    local sent = {}
    local realPopen = io.popen
    io.popen = popening({ "ok:\n", "ok:Yes\n", "ok:b'c\n" }, sent)
    local ok, answers = pcall(form.mac, "Zo\195\171's box", {
      { key = "words", label = 'it\'s "a" \\ b', kind = "text", default = "" },
      { key = "loud", label = "Loud", kind = "check", default = false },
      { key = "which", label = "Which", kind = "choice", default = "a", choices = { "a", "b'c" } },
    })
    io.popen = realPopen
    t:ok(ok, tostring(answers))
    t:eq(answers and answers.words, "", "an empty answer")
    t:eq(answers and answers.loud, true)
    t:eq(answers and answers.which, "b'c")
    t:ok(sent[1]:find([[display dialog "it'\''s \"a\" \\ b" default answer ""]], 1, true), sent[1])
    t:ok(sent[1]:find([[with title "Zo]] .. "\195\171" .. [['\''s box"]], 1, true), sent[1])
    t:ok(sent[2]:find([[default button "No"]], 1, true), sent[2])
    t:ok(sent[3]:find("-e 'if r is false then error number -128'", 1, true), sent[3])
    t:ok(sent[3]:find([[choose from list {"a", "b'\''c"}]], 1, true), sent[3])
  end,

  form_on_a_mac_tells_cancel_from_a_failure = function(t)
    local form = helpers.load(ASK, "form")
    local fields = { { key = "words", label = "Words", kind = "text", default = "" } }
    local realPopen = io.popen
    io.popen = popening({ "0:52: execution error: User canceled. (-128)\n" }, {})
    local cancelled, cancelWhy = form.mac("Box", fields)
    io.popen = popening({ "sh: osascript: command not found\n" }, {})
    local failed, why = form.mac("Box", fields)
    io.popen = popening({ "" }, {})
    local silent, silentWhy = form.mac("Box", fields)
    io.popen = realPopen
    t:eq(cancelled, nil)
    t:eq(cancelWhy, nil, "Cancel isn't a failure")
    t:eq(failed, nil)
    t:eq(why, "sh: osascript: command not found")
    t:eq(silent, nil)
    t:eq(silentWhy, "osascript gave no answer")
  end,
}
