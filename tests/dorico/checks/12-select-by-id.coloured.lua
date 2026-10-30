-- Run with 04-read-the-saved-copy.lua after 12-select-by-id.lua: the notes above F5 are red, the styled trumpet note
-- keeps its own colour unless it is one of them, and no other note has a colour. The command stores its colour for
-- the layout on screen, and that wins over a colour set with no context.
local checks = require("checks")

local RED = "#ffff0000"

return function(p, run)
  local styled = checks.expected().styled
  local above, wrong = {}, {}
  for _, key in ipairs(checks.notesAbove("F5")) do above[key] = true end
  local notes = checks.noteLines(run)
  for _, note in ipairs(notes) do
    local want = above[note.key] and RED or checks.isStyled(note) and styled.colour or "-"
    if note.colour ~= want then wrong[#wrong + 1] = note.line .. " (want " .. want .. ")" end
  end
  p:check("04 read every note", #notes == #checks.noteKeys(), #notes)
  p:check("every note has the colour it should", #wrong == 0, table.concat(wrong, " / "))
end
