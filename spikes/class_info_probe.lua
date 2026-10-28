-- Can a script list a luabind class's members? Tries luabind's class_info and class_names on a live score and a
-- class object, and lists the registry's tables that aren't under string keys, with a few of their keys each.
-- Read-only, and calls only luabind's own introspection functions. Scratch copy only (the probe confirms it).
local here = debug.getinfo(1, "S").source:match("^@(.*[/\\])")
local mine = here .. "?.lua;" .. here .. "lib/?.lua"
for name in pairs(package.loaded) do
  if package.searchpath(name, mine) then package.loaded[name] = nil end
end
if not package.path:find(mine, 1, true) then package.path = mine .. ";" .. package.path end
local probe = require("probe")

local function str(v)
  local ok, s = pcall(tostring, v)
  return ok and s or ("<" .. type(v) .. ">")
end

local function describe(v, depth)
  if type(v) ~= "table" or depth > 2 then return str(v) end
  local parts = {}
  for k, x in pairs(v) do parts[#parts + 1] = str(k) .. "=" .. describe(x, depth + 1) end
  table.sort(parts)
  return "{" .. table.concat(parts, ", "):sub(1, 3000) .. "}"
end

probe.run("class_info_probe", function(p)
  p:fact("globals", { class_info = type(rawget(_G, "class_info")), class_names = type(rawget(_G, "class_names")) })
  local score = DoApp.DoApp().currentScore
  for label, value in pairs({ score = score, scoreClass = DoScore.Score, flow = score.flows[1],
    stream = score.flows[1].voiceStreams[1] }) do
    local ok, info = pcall(function() return class_info(value) end)
    p:fact("class_info " .. label, ok and describe(info, 0) or ("error: " .. tostring(info)))
  end
  local ok, names = pcall(function() return class_names() end)
  p:fact("class_names", ok and describe(names, 0) or ("error: " .. tostring(names)))
  local others = {}
  for k, v in pairs(debug.getregistry()) do
    if type(k) ~= "string" and type(v) == "table" then
      local ks = {}
      for kk in pairs(v) do
        ks[#ks + 1] = str(kk)
        if #ks >= 12 then break end
      end
      others[#others + 1] = type(k) .. " " .. str(k) .. ": " .. table.concat(ks, " ")
    end
  end
  table.sort(others)
  p:fact("registryOthers", others)
end)
