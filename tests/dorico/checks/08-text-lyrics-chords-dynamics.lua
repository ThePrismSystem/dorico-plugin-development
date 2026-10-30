-- 08-text-lyrics-chords-dynamics.lua printed the reading fixture's texts, lyrics, chord symbols and dynamics as
-- reading.expected.json lists them, the hairpin included.
local checks = require("checks")

local SUFFIX = { major = "", dominant = "7", minor = "m" }

return function(p, run)
  local want = checks.reading()
  local function has(line) return checks.printed(run, line) end
  for _, t in ipairs(want.texts) do
    local line = table.concat({ "text", t.flow, t.player, t.pos, t.above and "above" or "below", "staff",
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
    local found = false
    for _, line in ipairs(run.printed) do
      if line:sub(1, #prefix) == prefix then found = true end
    end
    p:check("chord " .. c.root .. " at " .. c.pos, found, prefix)
  end
  for _, d in ipairs(want.dynamics) do
    local prefix = table.concat({ "dynamic", d.flow, d.player, d.pos, d.name }, "\t") .. "\t"
    local found = false
    for _, line in ipairs(run.printed) do
      if line:sub(1, #prefix) == prefix then found = true end
    end
    p:check("dynamic " .. d.name .. " at " .. d.pos, found, prefix)
  end
  p:check("the hairpin", has(table.concat({ "dynamic", 1, "Flute", "12", "crescendo", "gradual" }, "\t")))
end
