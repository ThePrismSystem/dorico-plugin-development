-- 08-text-lyrics-chords-dynamics.lua printed the reading fixture's texts, lyrics, chord symbols and dynamics as
-- reading.expected.json lists them, the hairpin included, and a total that counts them. args.below names a text
-- flipped below the staff in the full score before the run.
local checks = require("checks")

local SUFFIX = { major = "", dominant = "7", minor = "m" }
-- The kind the reader gives each dynamic in the fixture; the rest are immediate.
local KINDS = { fp = "combined", sfz = "force" }

return function(p, run, args)
  local want = checks.reading()
  local below = args and args.below
  local function has(line) return checks.printed(run, line) end
  local function hasPrefix(prefix)
    for _, line in ipairs(run.printed) do
      if line:sub(1, #prefix) == prefix then return true end
    end
    return false
  end
  for _, t in ipairs(want.texts) do
    local above = t.above and t.words ~= below
    local line = table.concat({ "text", t.flow, t.player, t.pos, above and "above" or "below", "staff",
      "paragraph.defaulttext", t.words }, "\t")
    p:check("text " .. t.words, has(line), line)
  end
  for _, l in ipairs(want.lyrics) do
    local line = table.concat({ "lyric", l.flow, l.player, l.pos, l.line, l.syllable, l.text,
      l.extend and "melisma" or "-" }, "\t")
    p:check("lyric " .. l.text, has(line), line)
  end
  for _, c in ipairs(want.chords) do
    local prefix = table.concat({ "chord", c.flow, c.pos, c.root, c.root .. SUFFIX[c.chord] }, "\t") .. "\t"
    p:check("chord " .. c.root .. " at " .. c.pos, hasPrefix(prefix), prefix)
  end

  local dynamics = {}
  for _, d in ipairs(want.dynamics) do
    dynamics[#dynamics + 1] = table.concat({ "dynamic", d.flow, d.player, d.pos, d.name, KINDS[d.name] or "immediate" },
      "\t")
  end
  for _, h in ipairs(want.hairpins) do
    if h.type ~= "stop" then
      dynamics[#dynamics + 1] = table.concat({ "dynamic", h.flow, h.player, h.pos, h.type, "gradual" }, "\t")
    end
  end
  local got = {}
  for _, line in ipairs(run.printed) do
    if line:sub(1, 8) == "dynamic\t" then got[#got + 1] = line end
  end
  p:check("the dynamics and the hairpin, and nothing else", checks.joined(got) == checks.joined(dynamics),
    table.concat(got, " / "))

  local total = table.concat({ "total", #want.texts, #want.lyrics, #want.chords, #dynamics }, "\t")
  p:check("the total line", run.printed[#run.printed] == total, run.printed[#run.printed])
end
