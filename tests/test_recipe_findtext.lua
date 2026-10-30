-- The find and replace recipe's helpers: findtext matching and replacing words, one option per test, and rebuild
-- saying which matches can be replaced exactly.
local helpers = require("helpers")

local RECIPE = "examples/recipes/find-and-replace.lua"

local function findtext() return helpers.load(RECIPE, "findtext") end

-- rebuild.why for a text, lyric or chord symbol built from defaults and changes, with property entries as
-- {property, value, layout} (layout -1 for none).
local function why(kind, changes, entries, new)
  local e = ({
    text = { kind = "text", formatted = false, paragraphs = { { style = "paragraph.defaulttext" } }, above = true },
    lyric = { kind = "lyric", line = 1, syllable = "single", lineType = "verse", above = false,
      duration = { num = 0, den = 1 } },
    chordSymbol = { kind = "chordSymbol" },
  })[kind]
  for k, v in pairs(changes or {}) do e[k] = v end
  local list = {}
  for i, x in ipairs(entries or {}) do
    list[i] = { property = x[1], value = 'string: "' .. x[2] .. '"', layout = x[3] or -1, instance = -1 }
  end
  local reason, placement = helpers.load(RECIPE, "rebuild").why(e, list, new or "new", require("scorereader.values").typed)
  return tostring(reason) .. (placement and (" / " .. placement) or "")
end

-- "from-to" for each match, in order.
local function spans(words, query, opts)
  local out = {}
  for i, m in ipairs(findtext().matches(words, query, opts or {})) do out[i] = m.from .. "-" .. m.to end
  return table.concat(out, " ")
end

local function replaced(words, query, replacement, opts)
  local new, count = findtext().replace(words, query, replacement, opts or {})
  return new .. " (" .. count .. ")"
end

return {
  plain_text = function(t)
    t:eq(spans("dolce e dolce", "dolce"), "1-5 9-13")
    t:eq(spans("poco a poco", "a."), "", "a dot is only a dot")
    t:eq(spans("cresc.", "cresc."), "1-6")
    t:eq(replaced("dolce e dolce", "dolce", "sweet"), "sweet e sweet (2)")
  end,
  case = function(t)
    t:eq(spans("Dolce dolce", "dolce"), "1-5 7-11", "either case by default")
    t:eq(spans("Dolce dolce", "dolce", { matchCase = true }), "7-11")
    t:eq(replaced("Dolce", "DOLCE", "sweet"), "sweet (1)", "the replacement goes in as typed")
  end,
  whole_words = function(t)
    t:eq(spans("dolce dolcemente", "dolce", { wholeWord = true }), "1-5")
    t:eq(spans("(dolce)", "dolce", { wholeWord = true }), "2-6", "brackets aren't letters")
    t:eq(spans("caf\195\169s", "caf", { wholeWord = true }), "", "an accented letter is a letter")
    t:eq(spans("p mp", "p", { wholeWord = true }), "1-1")
  end,
  patterns_with_captures = function(t)
    t:eq(replaced("dolce e cantabile", "(%a+) e (%a+)", "%2 e %1", { pattern = true }), "cantabile e dolce (1)")
    t:eq(replaced("bar 12", "%d+", "[%0]", { pattern = true }), "bar [12] (1)")
    t:eq(spans("Dolce", "dolce", { pattern = true }), "", "a pattern matches case as written")
    t:eq(spans("abc", "x*", { pattern = true }), "", "a pattern that matches only nothing finds nothing")
    t:eq(spans("aa", "^a", { pattern = true }), "1-1", "^ anchors at the start only")
  end,
  nothing_to_find = function(t)
    t:eq(spans("dolce", "forte"), "")
    t:eq(replaced("dolce", "forte", "piano"), "dolce (0)")
    t:eq(replaced("dolce", "", "x"), "dolce (0)", "an empty search finds nothing")
  end,
  a_percent_sign_in_the_replacement = function(t)
    t:eq(replaced("50 per cent", "per cent", "%"), "50 % (1)", "plain text takes it as it is")
    t:eq(replaced("50 per cent", "per cent", "%%", { pattern = true }), "50 % (1)", "a pattern writes %% for one")
  end,
  a_broken_pattern_stops_with_an_error = function(t)
    t:ok(not pcall(findtext().matches, "dolce", "[d", { pattern = true }))
  end,
  a_capture_the_pattern_doesnt_have_stops_with_an_error = function(t)
    local ok, err = pcall(findtext().replace, "dolce", "(d)(o)", "%3", { pattern = true })
    t:ok(not ok)
    t:eq(err, "the pattern has no capture 3")
  end,
  texts_that_can_be_rebuilt = function(t)
    t:eq(why("text"), "nil", "a plain text above the staff")
    t:eq(why("text", nil, { { "kTextEventAboveOrBelow", "kBelow" } }), "nil / kBelow", "below for every layout")
    t:eq(why("text", { above = false }), "nil / kBelow", "below as written")
  end,
  texts_that_cant = function(t)
    t:eq(why("text", nil, { { "kTextEventAboveOrBelow", "kBelow", 0 } }),
      "it is above or below the staff in one layout only", "flipped with a layout on screen")
    t:eq(why("text", nil, { { "kEventColour", "#ff0000c0" } }), "it has settings of its own (kEventColour)")
    t:eq(why("text", { formatted = true }), "it has formatting inside it")
    t:eq(why("text", { paragraphs = { { style = "paragraph.user.default_text_2" } } }),
      "it is in another paragraph style")
    t:eq(why("text", { paragraphs = { { style = "paragraph.defaulttext" }, { style = "paragraph.defaulttext" } } }),
      "it has more than one paragraph")
    t:eq(why("text", nil, nil, ""), "the new words are empty")
  end,
  lyrics = function(t)
    t:eq(why("lyric"), "nil", "a whole word on line 1")
    t:eq(why("lyric", { line = 2 }), "only a whole-word verse lyric on line 1 can be replaced")
    t:eq(why("lyric", { syllable = "begin" }), "only a whole-word verse lyric on line 1 can be replaced")
    t:eq(why("lyric", { lineType = "chorus" }), "only a whole-word verse lyric on line 1 can be replaced")
    t:eq(why("lyric", { duration = { num = 1, den = 1 } }), "it has a melisma line")
    t:eq(why("lyric", { above = true }), "it is above the staff")
    t:eq(why("lyric", nil, { { "kEventColour", "#ff0000c0" } }), "it has settings of its own (kEventColour)")
    t:eq(why("lyric", nil, nil, "two words"), "the new lyric isn't a single word")
    t:eq(why("lyric", nil, nil, "hap-"), "the new lyric isn't a single word")
  end,
  chord_symbols = function(t)
    t:eq(why("chordSymbol", nil, nil, "Dm7"), "nil")
    t:eq(why("chordSymbol", nil, { { "kEventColour", "#ff0000c0" } }), "it has settings of its own (kEventColour)")
    t:eq(why("chordSymbol", nil, nil, "D m"), "the new chord symbol isn't one word")
  end,
}
