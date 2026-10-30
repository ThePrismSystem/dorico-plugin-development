-- 04-read-the-saved-copy.lua read the sample's format, found the trumpet's styled note with its notehead and colour,
-- read every other note as plain, printed nothing else, and deleted the copy it read.
local checks = require("checks")

return function(p, run)
  local styled = checks.expected().styled
  local notes, format, others = checks.noteLines(run)
  local got, found, plain = {}, 0, 0
  for _, note in ipairs(notes) do
    got[#got + 1] = note.key
    if checks.isStyled(note) then
      found = found + 1
      p:check("the styled note's notehead", note.notehead == styled.notehead, note.notehead)
      p:check("the styled note's colour", note.colour == styled.colour, note.colour)
    elseif note.notehead == "-" and note.colour == "-" then
      plain = plain + 1
    else
      p:check("no other note is styled", false, note.line)
    end
  end
  p:check("the format line", format and format[2]:match("^1%.%d+$") and format[3] == "known",
    format and table.concat(format, " "))
  p:check("the styled note was found once", found == 1, found)
  local keys = checks.noteKeys()
  p:check("every note, at its position", checks.joined(got) == checks.joined(keys),
    "got " .. checks.joined(got) .. " | want " .. checks.joined(keys))
  p:check("every other note is plain", plain == #keys - 1, plain)
  p:check("nothing else printed", #others == 0, table.concat(others, " / "))

  -- where scorereader.dorico.savedcopy puts its copy by default
  local copy = ((os.getenv("TEMP") or os.getenv("TMPDIR") or "/tmp"):gsub("\\", "/")) .. "/scorereader-copy.dorico"
  local f = io.open(copy, "rb")
  if f then f:close() end
  p:check("the saved copy was deleted", f == nil, copy)
end
