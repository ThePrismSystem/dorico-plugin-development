-- colour-by-pitch.lua counted the sample's notes by pitch class and named each class's colour. Whether the notes
-- have their colours is colour-by-pitch.coloured.lua's question (it reads them through 04's paste, in a later run).
local checks = require("checks")

local NAMES = { [0] = "C", "C#/Db", "D", "D#/Eb", "E", "F", "F#/Gb", "G", "G#/Ab", "A", "A#/Bb", "B" }
local COLOURS = {
  [0] = "#ffe41a1c", "#fff4511e", "#ffff7f00", "#ffffb300", "#ffd4b000", "#ff4daf4a",
  "#ff1b9e77", "#ff00a0b0", "#ff1f78b4", "#ff3f51b5", "#ff7b3294", "#ffc51b7d",
}

return function(p, run)
  local midi = checks.helper("examples/fundamentals/12-select-by-id.lua", { "midi" }, "midi")
  local counts = {}
  for _, flow in ipairs(checks.expected().flows) do
    for _, player in ipairs(flow.players) do
      for _, note in ipairs(player.notes) do
        local class = midi(note.spelling) % 12
        counts[class] = (counts[class] or 0) + 1
      end
    end
  end
  local want = {}
  for class = 0, 11 do
    if counts[class] then
      want[#want + 1] = string.format("%s: %d notes, %s", NAMES[class], counts[class], COLOURS[class])
    end
  end
  p:check("a count per pitch class", table.concat(run.printed, " / ") == table.concat(want, " / "),
    table.concat(run.printed, " / "))
  checks.musicUnchanged(p)
end
