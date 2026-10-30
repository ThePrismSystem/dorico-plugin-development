-- Every bound class's members, written to <run folder>/members-raw.json for docs/reference/members.json. Read-only,
-- and it calls nothing it finds. Scratch copy only (the probe confirms it). After the handbells repository's
-- spike/17_api_map.lua.
--
-- luabind keeps each class's members in tables in Lua's registry, under numbers: one for the class object's own
-- (static) members, one for its instances'. Every member is a function there, properties included. The probe names
-- the static tables by looking up one of each table's members on each class object (DoCore.Variant and so on), which
-- hands back the member without calling it; the class whose lookup returns the same function owns the table. It
-- doesn't look anything up on an instance, since that would run a property's getter. tools/members.py names the
-- instance tables afterwards, by the members they hold.
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

probe.run("class_members", function(p)
  local json = require("json")
  local classes = {}
  for _, g in ipairs({ "DoApp", "DoCore", "DoScore", "DoUI" }) do
    local t = rawget(_G, g)
    if type(t) == "table" then
      for name, rep in pairs(t) do classes[#classes + 1] = { name = g .. "." .. str(name), rep = rep } end
    end
  end
  table.sort(classes, function(a, b) return a.name < b.name end)

  local out, unmatched = {}, {}
  for key, tbl in pairs(debug.getregistry()) do
    if type(key) == "number" and type(tbl) == "table" and next(tbl) ~= nil then
      local members, probeKey = {}, nil
      for k, v in pairs(tbl) do
        local name = str(k)
        members[#members + 1] = { name = name, kind = type(v) }
        if type(v) == "function" and (not probeKey or (probeKey:match("^__") and not name:match("^__"))) then
          probeKey = name
        end
      end
      table.sort(members, function(a, b) return a.name < b.name end)
      local owner
      if probeKey then
        for _, c in ipairs(classes) do
          local ok, v = pcall(function() return c.rep[probeKey] end)
          if ok and rawequal(v, tbl[probeKey]) then owner = c.name end
        end
      end
      if owner then
        out[owner] = members
      else
        unmatched[#unmatched + 1] = { registry = key, members = members }
      end
    end
  end
  local names = {}
  for _, c in ipairs(classes) do names[#names + 1] = c.name end
  local f = assert(io.open(probe.runDir .. "members-raw.json", "wb"))
  f:write(json.encode({ dorico = DoApp.DoApp().versionString, classes = names, members = out, unmatched = unmatched }))
  f:close()
  local count = 0
  for _ in pairs(out) do count = count + 1 end
  p:fact("named", count)
  p:fact("unmatched", #unmatched)
  p:fact("classes", #classes)
end)
