-- 07-values-per-layout.lua printed each property the reading fixture's notes were given, with the value the full
-- score and the player's part show: a value set with a part on screen shows only in that part, and one set by the
-- menu command with the full score on screen shows only in the full score.
local checks = require("checks")

return function(p, run)
  local got, entries = {}, {}
  for _, line in ipairs(run.printed) do
    local f = checks.fields(line)
    local key = table.concat({ f[2] or "", f[3] or "", f[4] or "", f[5] or "" }, "|")
    if f[1] == "value" then got[key] = { full = f[6], part = f[7] } end
    if f[1] == "entry" then entries[key] = (entries[key] or "") .. (f[7] or "") .. ";" end
  end
  for _, want in ipairs(checks.reading().props) do
    local key = table.concat({ want.player, want.pos, want.spelling, want.property }, "|")
    local v = got[key]
    if p:check(key .. " is listed", v ~= nil) then
      p:check(key .. " in the full score", v.full == (want.how == "part" and "-" or want.value), v.full)
      p:check(key .. " in the part", v.part == (want.how == "menu" and "-" or want.value), v.part)
    end
  end
  local command = entries["Flute|1|D5|kNoteheadSetOverride"] or ""
  p:check("the command's entry names its block instance", command:find("block instance", 1, true) ~= nil, command)
  local part = entries["Flute|2|E5|kEventColour"] or ""
  p:check("the part's entry names the part", part:find("layout Flute", 1, true) ~= nil, part)
end
