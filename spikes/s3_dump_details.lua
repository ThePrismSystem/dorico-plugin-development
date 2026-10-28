-- S3: what does stream:dump() say about ties, grace notes, time and key signatures, implicit rests and gaps? Writes
-- every stream's dump of every flow to <run folder>/s3-dumps.txt, and reports event kinds per stream type.
-- Read-only.
local here = debug.getinfo(1, "S").source:match("^@(.*[/\\])")
local mine = here .. "?.lua;" .. here .. "lib/?.lua"
for name in pairs(package.loaded) do
  if package.searchpath(name, mine) then package.loaded[name] = nil end
end
if not package.path:find(mine, 1, true) then package.path = mine .. ";" .. package.path end
local probe = require("probe")

probe.run("s3_dump_details", function(p)
  local app = DoApp.DoApp()
  local out = assert(io.open(probe.runDir .. "s3-dumps.txt", "wb"))
  local kinds = {}
  local TYPES = { [0] = "timebase", [1] = "stave", [2] = "voice", [3] = "player" }
  for fi, f in ipairs(app.currentScore.flows) do
    for _, s in ipairs(f.allStreams) do
      local okT, t = pcall(function() return s.type end)
      local typeName = okT and (TYPES[t] or tostring(t)) or "?"
      local okD, d = pcall(function() return s:dump() end)
      out:write(string.format("=== flow %d (id %d) stream %d, %s ===\n", fi, f.id, s.id, typeName))
      out:write(okD and d or ("dump failed: " .. tostring(d)), "\n")
      if okD then
        for tag in d:gmatch(": (k%a+) %(id:") do
          local k = typeName .. " " .. tag
          kinds[k] = (kinds[k] or 0) + 1
        end
      end
    end
  end
  out:close()
  local list = {}
  for k, n in pairs(kinds) do list[#list + 1] = k .. " x" .. n end
  table.sort(list)
  p:fact("kinds", list)
  p:fact("dumps", probe.runDir .. "s3-dumps.txt")
end)
