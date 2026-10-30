-- The parallels helper from the parallel fifths recipe, on parts built by hand: one rule per test.
local helpers = require("helpers")

local RECIPE = "examples/recipes/parallel-fifths.lua"

-- A part from {pos, pitch} pairs, each note a quarter long unless a third value gives its length.
local function part(name, notes)
  local out = { name = name, notes = {} }
  for i, n in ipairs(notes) do
    out.notes[i] = { id = name .. i, pos = n[1], pitch = n[2], duration = n[3] or 1, grace = n.grace }
  end
  return out
end

local function find(parts, opts)
  return helpers.load(RECIPE, "parallels").find(parts, opts or {})
end

-- "kind a/b @pos" for each finding, in order.
local function brief(found)
  local out = {}
  for i, f in ipairs(found) do out[i] = f.kind .. " " .. f.a .. "/" .. f.b .. " @" .. f.pos end
  return table.concat(out, ", ")
end

local C3, D3, E3, F3, G3, A3, C4, D4, G4, A4, C5, D5, E5, G5 = 48, 50, 52, 53, 55, 57, 60, 62, 67, 69, 72, 74, 76, 79

return {
  consecutive_fifths = function(t)
    local found = find({ part("upper", { { 0, D5 }, { 1, E5 } }), part("lower", { { 0, G3 }, { 1, A3 } }) })
    t:eq(brief(found), "fifths upper/lower @1", "a compound fifth counts")
    t:eq(found[1].notes[1].id, "upper1")
    t:eq(#found[1].notes, 4, "both notes of both parts")
  end,
  consecutive_octaves_and_unisons = function(t)
    t:eq(brief(find({ part("a", { { 0, C5 }, { 1, D5 } }), part("b", { { 0, C3 }, { 1, D3 } }) })), "octaves a/b @1")
    t:eq(brief(find({ part("a", { { 0, G4 }, { 1, A4 } }), part("b", { { 0, G4 }, { 1, A4 } }) })), "unisons a/b @1")
    t:eq(brief(find({ part("a", { { 0, G4 }, { 1, A4 } }), part("b", { { 0, G4 }, { 1, A4 } }) }, { unisons = false })),
      "", "unisons can be left out")
  end,
  repeated_and_held_notes_are_no_motion = function(t)
    t:eq(brief(find({ part("a", { { 0, C5 }, { 1, C5 } }), part("b", { { 0, F3 }, { 1, F3 } }) })), "",
      "both repeat")
    t:eq(brief(find({ part("a", { { 0, C5, 2 } }), part("b", { { 0, F3 }, { 1, G3 } }) })), "", "one holds")
  end,
  a_rest_breaks_a_consecutive = function(t)
    local parts = { part("a", { { 0, D5 }, { 2, E5 } }), part("b", { { 0, G3 }, { 2, A3 } }) }
    t:eq(brief(find(parts)), "", "by default")
    t:eq(brief(find(parts, { restBreaks = false })), "fifths a/b @2", "unless asked")
  end,
  crossed_parts_stay_the_same_pair = function(t)
    local found = find({ part("violin", { { 0, C4 }, { 1, D4 } }), part("viola", { { 0, G4 }, { 1, A4 } }) })
    t:eq(brief(found), "fifths violin/viola @1")
  end,
  grace_notes_are_left_out = function(t)
    local found = find({ part("a", { { 0, D5 }, { 1, C5, 0, grace = true }, { 1, E5 } }),
      part("b", { { 0, G3 }, { 1, A3 } }) })
    t:eq(brief(found), "fifths a/b @1")
  end,
  a_doubling_is_not_a_consecutive = function(t)
    local line = { C3, D3, E3, F3, G3, A3 }
    local upper, lower = {}, {}
    for i, p in ipairs(line) do
      upper[i] = { i - 1, p + 12 }
      lower[i] = { i - 1, p }
    end
    local parts = { part("cello", upper), part("bassoon", lower) }
    t:eq(brief(find(parts)), "", "six notes in octaves")
    t:eq(#find(parts, { doublings = true }), 5, "unless asked")
    t:eq(brief(find({ part("cello", { { 0, E3 + 12 }, { 1, F3 + 12 } }), part("bassoon", { { 0, E3 }, { 1, F3 } }) })),
      "octaves cello/bassoon @1", "two notes are a consecutive")
  end,
  a_doubling_with_a_repeated_note_or_another_rhythm = function(t)
    local scale = { 60, 62, 64, 64, 65, 67 }
    local upper, lower = {}, {}
    for i, p in ipairs(scale) do
      upper[i] = { i - 1, p + 12 }
      lower[i] = { i - 1, p }
    end
    t:eq(brief(find({ part("flute", upper), part("violin", lower) })), "", "a repeated note in both parts")
    local halves, quarters = {}, {}
    for i, p in ipairs({ 60, 62, 64, 65, 67 }) do
      halves[i] = { 2 * (i - 1), p + 12, 2 }
      quarters[#quarters + 1] = { 2 * (i - 1), p }
      quarters[#quarters + 1] = { 2 * (i - 1) + 1, p }
    end
    t:eq(brief(find({ part("flute", halves), part("violin", quarters) })), "", "half notes over repeated quarters")
    local leaves = { part("flute", { { 0, 72 }, { 1, 74 }, { 2, 74 }, { 3, 76 } }),
      part("violin", { { 0, 60 }, { 1, 62 }, { 2, 65 }, { 3, 64 } }) }
    t:eq(brief(find(leaves)), "octaves flute/violin @1", "a part leaving the octave ends the doubling")
  end,
  hidden_fifths_between_the_outer_parts = function(t)
    local parts = { part("top", { { 0, D5 }, { 1, G5 } }), part("bottom", { { 0, 45 }, { 1, C3 } }) }
    t:eq(brief(find(parts)), "", "off by default")
    t:eq(brief(find(parts, { hidden = true })), "hidden fifths top/bottom @1")
    local inner = { part("top", { { 0, 84 }, { 1, 84 } }), part("a", { { 0, D5 }, { 1, G5 } }),
      part("b", { { 0, 45 }, { 1, C3 } }), part("bottom", { { 0, 36 }, { 1, 36 } }) }
    t:eq(brief(find(inner, { hidden = true })), "", "not between inner parts")
    t:eq(brief(find({ part("top", { { 0, E5 }, { 1, G5 } }), part("bottom", { { 0, A3 }, { 1, C4 } }) },
      { hidden = true })), "fifths top/bottom @1", "a parallel fifth is not a hidden one")
  end,
  contrary_octaves = function(t)
    local parts = { part("top", { { 0, C5 }, { 1, D5 } }), part("bottom", { { 0, C3 }, { 1, 38 } }) }
    t:eq(brief(find(parts)), "", "off by default")
    t:eq(brief(find(parts, { contrary = true })), "contrary octaves top/bottom @1")
  end,
  outer_parts_only = function(t)
    local parts = { part("s", { { 0, 84 }, { 1, 84 } }), part("a", { { 0, C5 }, { 1, D5 } }),
      part("t", { { 0, 65 }, { 1, G4 } }), part("b", { { 0, 36 }, { 1, 36 } }) }
    t:eq(brief(find(parts)), "fifths a/t @1", "every pair by default")
    t:eq(brief(find(parts, { outerOnly = true })), "", "only s and b when asked")
  end,
  the_fixture_gives_the_findings_worked_out_by_hand = function(t)
    local score, values, json = require("scorereader.score"), require("scorereader.values"), require("json")
    local here = debug.getinfo(1, "S").source:match("^@(.*[/\\])") or "./"
    local f = assert(io.open(here .. "../fixtures/parallels.expected.json", "rb"))
    local want = json.decode(f:read("*a"))
    f:close()
    local s = score.readFile(here .. "../fixtures/6.2.30/parallels.dorico")
    local parts = helpers.load(RECIPE, "lines").of(s, s.flows[1], values)
    local function wanted(...)
      local out = {}
      for _, list in ipairs({ ... }) do
        for _, w in ipairs(list) do out[#out + 1] = w.kind .. " " .. w.a .. "/" .. w.b .. " @" .. w.pos end
      end
      table.sort(out, function(x, y) return tonumber(x:match("@(%d+)")) < tonumber(y:match("@(%d+)")) end)
      return table.concat(out, ", ")
    end
    t:eq(#parts, 5, "a part per player")
    t:eq(brief(find(parts)), wanted(want.findings.default))
    t:eq(brief(find(parts, { hidden = true, contrary = true })),
      wanted(want.findings.default, want.findings.hiddenAndContrary))
    t:eq(brief(find(parts, { doublings = true })), wanted(want.findings.default, want.findings.doublings))
  end,
  findings_come_in_time_order = function(t)
    local found = find({ part("a", { { 0, D5 }, { 1, E5 }, { 3, C5 }, { 4, D5 } }),
      part("b", { { 0, G3 }, { 1, A3 }, { 3, C3 }, { 4, D3 } }) })
    t:eq(brief(found), "fifths a/b @1, octaves a/b @4")
  end,
}
