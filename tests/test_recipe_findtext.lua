-- The findtext helper from the find and replace recipe: matching and replacing words, one option per test.
local helpers = require("helpers")

local RECIPE = "examples/recipes/find-and-replace.lua"

local function findtext() return helpers.load(RECIPE, "findtext") end

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
}
