-- The cautionary helper from the cautionary accidentals recipe, on notes built by hand: one rule per test.
local helpers = require("helpers")

local RECIPE = "examples/recipes/cautionary-accidentals.lua"

-- A note: id, spelling, bar, and optionally beat (1 to 4 in 4/4), endBar (a tie into a later bar), staff, instrument
-- and override (an accidental the user set).
local function n(id, spelling, bar, more)
  more = more or {}
  return { id = id, spelling = spelling, bar = bar, pos = (bar - 1) * 4 + (more.beat or 1) - 1,
    endBar = more.endBar or bar, staff = more.staff or "1:0", instrument = more.instrument or 1,
    override = more.override }
end

local DEFAULTS = { lookBack = 4, restsCount = true, otherStaves = true, otherInstruments = false }

local function find(notes, opts, keys)
  local o = {}
  for k, v in pairs(DEFAULTS) do o[k] = v end
  for k, v in pairs(opts or {}) do o[k] = v end
  if opts and opts.lookBack == false then o.lookBack = nil end
  return helpers.load(RECIPE, "cautionary").find(notes, keys or { { pos = 0, fifths = 0 } }, o)
end

-- "id<from:reason" for each note found, in order.
local function brief(found)
  local out = {}
  for i, f in ipairs(found) do out[i] = f.id .. "<" .. f.from .. ":" .. f.reason end
  return table.concat(out, ", ")
end

return {
  an_accidental_two_bars_back = function(t)
    t:eq(brief(find({ n("a", "F#5", 1), n("b", "F5", 3) })), "b<a:bars")
    t:eq(brief(find({ n("a", "F#5", 1), n("b", "F4", 3) })), "b<a:bars", "in any octave")
  end,
  a_return_to_the_key_signature = function(t)
    local eb = { { pos = 0, fifths = -3 } }
    t:eq(brief(find({ n("a", "A4", 1), n("b", "Ab4", 3) }, nil, eb)), "b<a:bars", "Ab after A natural in Eb")
    t:eq(brief(find({ n("a", "A4", 1), n("b", "A4", 3) }, nil, eb)), "", "an A natural shows its own")
  end,
  how_far_back = function(t)
    local two, four, ten = { n("a", "C#5", 1), n("b", "C5", 3) }, { n("a", "C#5", 1), n("b", "C5", 5) },
      { n("a", "C#5", 1), n("b", "C5", 11) }
    t:eq(brief(find(two, { lookBack = 2 })), "b<a:bars", "two bars back with 2")
    t:eq(brief(find(four, { lookBack = 2 })), "", "four bars back with 2")
    t:eq(brief(find(four, { lookBack = 4 })), "b<a:bars", "four bars back with 4")
    t:eq(brief(find(ten, { lookBack = 4 })), "", "ten bars back with 4")
    t:eq(brief(find(ten, { lookBack = false })), "b<a:bars", "ten bars back with no limit")
  end,
  bars_of_rest = function(t)
    local notes = { n("a", "G#4", 1), n("b", "G4", 7) }
    t:eq(brief(find(notes)), "", "five bars of rest count")
    t:eq(brief(find(notes, { restsCount = false })), "b<a:bars", "bars of rest don't count")
    local busy = { n("a", "G#4", 1), n("x1", "C5", 3), n("x2", "C5", 4), n("x3", "C5", 5), n("x4", "C5", 6),
      n("b", "G4", 7) }
    t:eq(brief(find(busy, { restsCount = false })), "", "bars with notes still count")
  end,
  a_tie_across_barlines = function(t)
    t:eq(brief(find({ n("a", "D#5", 1, { endBar = 3 }), n("b", "D5", 3, { beat = 3 }) })), "b<a:tie",
      "tied over two barlines")
    t:eq(brief(find({ n("a", "D#5", 1, { endBar = 2 }), n("b", "D5", 2, { beat = 3 }) })), "",
      "tied into the next bar, which Dorico's own rules decide")
  end,
  the_other_staff_of_the_instrument = function(t)
    local notes = { n("a", "A#4", 1, { staff = "1:0" }), n("b", "A3", 2, { staff = "1:1" }) }
    t:eq(brief(find(notes)), "b<a:otherStaff")
    t:eq(brief(find(notes, { otherStaves = false })), "")
    t:eq(brief(find({ n("a", "A#4", 1, { staff = "1:0" }), n("b", "A3", 1, { staff = "1:1", beat = 3 }) })),
      "b<a:otherStaff", "in the same bar")
  end,
  other_instruments = function(t)
    local notes = { n("a", "Bb4", 1, { instrument = 2, staff = "2:0" }), n("b", "B4", 2) }
    t:eq(brief(find(notes)), "", "off by default")
    t:eq(brief(find(notes, { otherInstruments = true })), "b<a:otherInstrument")
    local heard = { n("a", "Bb4", 1), n("x", "B4", 2, { instrument = 2, staff = "2:0" }), n("b", "B4", 3) }
    t:eq(brief(find(heard, { otherInstruments = true })), "x<a:otherInstrument, b<a:bars",
      "another instrument's B natural reminds no one else")
  end,
  notes_already_showing_an_accidental = function(t)
    t:eq(brief(find({ n("a", "F#5", 1), n("b", "F5", 3, { override = true }) })), "", "one the user set")
    t:eq(brief(find({ n("a", "F#5", 1), n("b", "F5", 3), n("c", "F#5", 3, { beat = 2 }) })), "b<a:bars",
      "the F# after it shows its own")
    t:eq(brief(find({ n("a", "F#5", 1), n("x", "F#5", 3), n("b", "F5", 3, { beat = 2 }) })), "",
      "an F natural after an F# in the same bar shows its own")
  end,
  what_dorico_decides = function(t)
    t:eq(brief(find({ n("a", "Eb5", 1), n("b", "E5", 2) })), "", "the next bar")
    t:eq(brief(find({ n("a", "Eb5", 1), n("b", "E4", 1, { beat = 2 }) })), "", "another octave in the same bar")
    t:eq(brief(find({ n("a", "Eb5", 1), n("x", "Eb5", 3), n("b", "E5", 4) })), "",
      "an accidental in the bar before, though an older one is further back")
  end,
  only_the_first_return = function(t)
    t:eq(brief(find({ n("a", "F#5", 1), n("b", "F5", 3), n("c", "F5", 4) })), "b<a:bars")
    t:eq(brief(find({ n("a", "F#5", 1), n("b", "F5", 3, { override = true }), n("c", "F5", 4) })), "",
      "a note the user marked reminds too")
  end,
  a_key_change_between = function(t)
    local keys = { { pos = 0, fifths = 0 }, { pos = 4, fifths = -3 } }
    t:eq(brief(find({ n("a", "B4", 1), n("b", "Bb4", 3) }, nil, keys)), "", "the new key signature shows the flat")
  end,
  the_fixture_gives_the_findings_worked_out_by_hand = function(t)
    local score, values, json = require("scorereader.score"), require("scorereader.values"), require("json")
    local here = debug.getinfo(1, "S").source:match("^@(.*[/\\])") or "./"
    local f = assert(io.open(here .. "../fixtures/cautionary.expected.json", "rb"))
    local want = json.decode(f:read("*a"))
    f:close()
    local s = score.readFile(here .. "../fixtures/6.2.30/cautionary.dorico")
    local flow = s.flows[1]
    local bars, staffnotes = helpers.load(RECIPE, "bars"), helpers.load(RECIPE, "staffnotes")
    local divisions, endPos = {}, 0
    for _, e in ipairs(flow.events) do
      endPos = math.max(endPos, values.toNumber(e.position) + values.toNumber(e.duration))
      if e.kind == "timeSignature" then
        divisions[#divisions + 1] = { pos = values.toNumber(e.position), numerator = e.numerator,
          denominator = e.denominator }
      end
    end
    local starts = bars.starts(divisions, endPos)
    local notes, keys = staffnotes.of(flow, values, bars, starts)
    t:eq(#notes, #want.notes, "every note, a tied one once")
    t:eq(#keys, 2, "C major, then E-flat at " .. keys[2].pos)
    t:eq(keys[2].pos, want.keyChange)
    local byId, player = {}, {}
    for _, p in ipairs(s.players) do player[p.instruments[1].id] = p.name end
    for _, x in ipairs(notes) do
      byId[x.id] = x
      for _, e in ipairs(score.entries(s, x.event)) do
        if e.property == "kNoteAccidentalVisibility_v3" then x.override = true end
      end
    end
    local function got(opts)
      local out = {}
      for _, found in ipairs(find(notes, opts, keys)) do
        local x = byId[found.id]
        out[#out + 1] = player[x.instrument] .. " " .. x.spelling .. " bar " .. x.bar
      end
      return table.concat(out, ", ")
    end
    local function wanted(list)
      local out = {}
      for _, w in ipairs(list) do out[#out + 1] = w.player .. " " .. w.spelling .. " bar " .. w.bar end
      return table.concat(out, ", ")
    end
    t:eq(got(), wanted(want.findings.default))
    t:eq(got({ lookBack = 2 }), wanted(want.findings.lookBack2))
    t:eq(got({ lookBack = false }), wanted(want.findings.noLimit))
    t:eq(got({ restsCount = false }), wanted(want.findings.restsDontCount))
    t:eq(got({ otherStaves = false }), wanted(want.findings.noOtherStaves))
    t:eq(got({ otherInstruments = true }), wanted(want.findings.otherInstruments))
  end,
  in_time_order = function(t)
    local found = find({ n("a", "F#5", 1), n("c", "C#5", 1, { beat = 2 }), n("d", "C5", 3), n("b", "F5", 3,
      { beat = 2 }) })
    t:eq(brief(found), "d<c:bars, b<a:bars")
  end,
}
