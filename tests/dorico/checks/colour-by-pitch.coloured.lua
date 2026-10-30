-- Run with 04-read-the-saved-copy.lua after colour-by-pitch.lua: every note has its pitch class's colour, the styled
-- trumpet note included, since the command's colour wins over one set with no context.
local checks = require("checks")

-- colour-by-pitch.lua's COLOURS, C first.
local COLOURS = { [0] = "#ffe41a1c", "#fff4511e", "#ffff7f00", "#ffffb300", "#ffd4b000", "#ff4daf4a",
  "#ff1b9e77", "#ff00a0b0", "#ff1f78b4", "#ff3f51b5", "#ff7b3294", "#ffc51b7d" }

return function(p, run)
  local midi = checks.helper("examples/fundamentals/12-select-by-id.lua", { "midi" }, "midi")
  local wrong = {}
  local notes = checks.noteLines(run)
  for _, note in ipairs(notes) do
    local want = COLOURS[midi(note.spelling) % 12]
    if note.colour ~= want then wrong[#wrong + 1] = note.line .. " (want " .. want .. ")" end
  end
  p:check("04 read every note", #notes == #checks.noteKeys(), #notes)
  p:check("every note has its pitch class's colour", #wrong == 0, table.concat(wrong, " / "))
end
