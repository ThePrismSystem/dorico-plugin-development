-- The names helper from the note names recipe: every naming system, accidentals, octaves, keys and transposition.
local helpers = require("helpers")

local RECIPE = "examples/recipes/note-names.lua"
local SHARP, FLAT = "\226\153\175", "\226\153\173"

local function names() return helpers.load(RECIPE, "names") end

return {
  english_names_with_accidentals_and_octaves = function(t)
    local n = names()
    t:eq(n.of("F#5", "english"), "F" .. SHARP)
    t:eq(n.of("F#5", "english", { octave = true }), "F" .. SHARP .. "5")
    t:eq(n.of("Eb4", "english"), "E" .. FLAT)
    t:eq(n.of("Dx4", "english"), "D" .. SHARP .. SHARP)
    t:eq(n.of("Ebb4", "english"), "E" .. FLAT .. FLAT)
    t:eq(n.of("B3", "english"), "B")
    t:eq(n.of("C-1", "english", { octave = true }), "C-1", "the lowest octave")
  end,
  german_names = function(t)
    local n = names()
    for spelling, want in pairs({ B3 = "H", Bb3 = "B", Eb4 = "Es", Ab4 = "As", ["F#5"] = "Fis", Cb4 = "Ces",
      Bbb3 = "Heses", Ebb4 = "Eses", Abb4 = "Ases", Dx4 = "Disis", ["E#4"] = "Eis", ["B#3"] = "His", Gb4 = "Ges" }) do
      t:eq(n.of(spelling, "german"), want, spelling)
    end
  end,
  fixed_do = function(t)
    local n = names()
    t:eq(n.of("F#5", "fixed-it"), "Fa" .. SHARP)
    t:eq(n.of("D4", "fixed-fr"), "R\195\169")
    t:eq(n.of("B3", "fixed-es"), "Si")
    t:eq(n.of("G4", "fixed-it", { octave = true }), "Sol4")
  end,
  movable_do_follows_the_key = function(t)
    local n = names()
    local g = { key = { fifths = 1, mode = "major" } }
    t:eq(n.of("G4", "movable", g), "do")
    t:eq(n.of("F#5", "movable", g), "ti")
    t:eq(n.of("F5", "movable", g), "te", "lowered ti")
    t:eq(n.of("C#5", "movable", g), "fi", "raised fa")
    t:eq(n.of("Bb4", "movable", g), "me", "lowered mi")
    t:eq(n.of("A4", "movable", { key = { fifths = 0, mode = "minor" } }), "la", "a minor key keeps its major's do")
    t:eq(n.of("C4", "movable"), "do", "no key is C major")
  end,
  scale_degrees_follow_the_key_and_mode = function(t)
    local n = names()
    local g = { key = { fifths = 1, mode = "major" } }
    t:eq(n.of("G4", "degrees", g), "1")
    t:eq(n.of("F#5", "degrees", g), "7")
    t:eq(n.of("F5", "degrees", g), FLAT .. "7")
    t:eq(n.of("C#5", "degrees", g), SHARP .. "4")
    local a = { key = { fifths = 0, mode = "minor" } }
    t:eq(n.of("A4", "degrees", a), "1")
    t:eq(n.of("C5", "degrees", a), "3")
    t:eq(n.of("G#4", "degrees", a), SHARP .. "7")
  end,
  written_pitch_for_transposing_instruments = function(t)
    local n = names()
    t:eq(n.written("C5", { diatonic = 1, chromatic = 2 }), "D5", "B-flat clarinet")
    t:eq(n.written("Bb4", { diatonic = 1, chromatic = 2 }), "C5")
    t:eq(n.written("C5", { diatonic = 2, chromatic = 3 }), "Eb5", "A clarinet")
    t:eq(n.written("C3", { diatonic = 7, chromatic = 12 }), "C4", "guitar")
    t:eq(n.written("F#4", { diatonic = -1, chromatic = -2 }), "E4", "D trumpet")
    t:eq(n.written("B4", { diatonic = 1, chromatic = 2 }), "C#5")
    t:eq(n.written("F4", nil), "F4", "no transposition")
  end,
  chords_stack_top_first = function(t)
    local n = names()
    t:eq(n.chord({ "C4", "E4", "G4" }, "english"), "G\nE\nC")
  end,
  the_written_key_for_written_names = function(t)
    local n = names()
    local clarinet = { diatonic = 1, chromatic = 2 }
    local g = n.writtenKey({ fifths = 1, mode = "major" }, clarinet)
    t:eq(g.fifths, 3, "concert G major is written in A major")
    t:eq(n.of(n.written("G4", clarinet), "movable", { key = g }), "do", "the tonic stays do")
    t:eq(n.of(n.written("G4", clarinet), "degrees", { key = g }), "1")
    t:eq(n.writtenKey({ fifths = 0, mode = "minor" }, { diatonic = 2, chromatic = 3 }).fifths, -3, "A clarinet")
    t:eq(n.writtenKey({ fifths = 0, mode = "major" }, { diatonic = 7, chromatic = 12 }).fifths, 0, "guitar")
    t:eq(n.writtenKey({ fifths = 1, mode = "major" }, nil).fifths, 1, "no transposition")
    local fSharp = n.writtenKey({ fifths = 6, mode = "major" }, clarinet)
    t:eq(n.of(n.written("F#4", clarinet), "movable", { key = fSharp }), "do", "G# major, past seven sharps")
  end,
  no_key_signature_is_concert_c_major = function(t)
    local n = names()
    local trumpet = { diatonic = 1, chromatic = 2 }
    t:eq(n.writtenKey(nil, trumpet).fifths, 2, "a B-flat trumpet's part is in D major")
    t:eq(n.writtenKey(nil, nil).fifths, 0, "an instrument in C is in C major")
    local cMajor = n.writtenKey({ fifths = 0, mode = "major" }, trumpet)
    for _, system in ipairs({ "movable", "degrees" }) do
      local none = n.of(n.written("C5", trumpet), system, { key = n.writtenKey(nil, trumpet) })
      t:eq(none, n.of(n.written("C5", trumpet), system, { key = cMajor }), system .. ": as with an explicit C major")
    end
  end,
  knows_every_name_it_could_write = function(t)
    local n = names()
    for _, words in ipairs({ "C", "F" .. SHARP .. "5", "Heses", "R\195\169", "Sol4", "ti", "fi", FLAT .. "7", "1",
      "G\nE\nC", "do\nmi", "C-1" }) do
      t:ok(n.isName(words), words)
    end
    for _, words in ipairs({ "", "dolce", "C major", "8", "do re", "G\nhello" }) do
      t:ok(not n.isName(words), words)
    end
  end,
}
