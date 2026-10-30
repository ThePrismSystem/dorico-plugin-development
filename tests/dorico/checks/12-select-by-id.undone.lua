-- Run with 04-read-the-saved-copy.lua after 12-select-by-id.lua and one Edit > Undo: every colour the script set
-- is gone, and the styled trumpet note still has its own.
local checks = require("checks")

return function(p, run)
  local styled = checks.expected().styled
  local notes = checks.noteLines(run)
  local found, others = 0, {}
  for _, note in ipairs(notes) do
    if checks.isStyled(note) then
      found = found + 1
      p:check("the styled note keeps its colour", note.colour == styled.colour, note.colour)
    elseif note.colour ~= "-" then
      others[#others + 1] = note.line
    end
  end
  p:check("04 read every note", #notes == #checks.noteKeys(), #notes)
  p:check("the styled note was found once", found == 1, found)
  p:check("no other note has a colour", #others == 0, table.concat(others, " / "))
end
