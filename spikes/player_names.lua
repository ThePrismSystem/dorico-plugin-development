-- Read-only: each player's name as tostring(player) gives it, with its bytes, to see how Dorico spells names with
-- symbols such as a flat sign.
local here = debug.getinfo(1, "S").source:match("^@(.*[/\\])")
local mine = here .. "?.lua;" .. here .. "lib/?.lua"
for name in pairs(package.loaded) do
  if package.searchpath(name, mine) then package.loaded[name] = nil end
end
if not package.path:find(mine, 1, true) then package.path = mine .. ";" .. package.path end
local probe = require("probe")

probe.run("player_names", function(p)
  local names = {}
  for _, pl in ipairs(DoApp.DoApp().currentScore.players) do
    local n = tostring(pl)
    local bytes = {}
    for i = 1, #n do bytes[#bytes + 1] = string.format("%02x", n:byte(i)) end
    names[#names + 1] = n .. " | " .. table.concat(bytes, " ")
  end
  p:fact("players", names)
end)
