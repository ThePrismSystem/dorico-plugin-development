-- S3, element tables: the dump gives a bar division, tonality division or dynamic only an "element ID". Does
-- flow.elementTables say what each one is (the time signature, the key, the dynamic level)? Read-only: it reads
-- members and tostring() of what it finds, and calls no constructor.
local here = debug.getinfo(1, "S").source:match("^@(.*[/\\])")
local mine = here .. "?.lua;" .. here .. "lib/?.lua"
for name in pairs(package.loaded) do
  if package.searchpath(name, mine) then package.loaded[name] = nil end
end
if not package.path:find(mine, 1, true) then package.path = mine .. ";" .. package.path end
local probe = require("probe")

local function try(fn)
  local ok, v = pcall(fn)
  if not ok then return "error: " .. tostring(v):sub(1, 160) end
  return v
end

-- Every value a few likely member names give, plus tostring and the length.
local function describe(obj, names)
  local out = { tostring = tostring(try(function() return tostring(obj) end)),
    len = tostring(try(function() return #obj end)) }
  for _, n in ipairs(names) do
    local v = try(function() return obj[n] end)
    if v ~= nil then out[n] = tostring(try(function() return tostring(v) end)) end
  end
  return out
end

local MEMBERS = { "id", "type", "data", "element", "elements", "items", "value", "values", "numerator",
  "denominator", "beats", "beatType", "timeSignature", "tonality", "key", "fifths", "mode", "dynamic", "dynamics",
  "level", "intensity", "name", "barDivisions", "tonalityDivisions", "find", "get", "count", "size" }

-- Every property an element (or sub-element) carries, with its value.
local function properties(el)
  local out = {}
  local ctx = DoCore.PropertyContext()
  local names = try(function() return el.propertyTable:getPropertyNames() end)
  if type(names) ~= "table" then return { names = tostring(names) } end
  for _, n in ipairs(names) do
    out[tostring(n)] = tostring(try(function() return tostring(el.propertyTable:get(n, ctx)) end))
  end
  return out
end

local function walk(t)
  local out = {}
  local els = try(function() return t.elements end)
  if type(els) ~= "table" then return { elements = tostring(els) } end
  for k, el in pairs(els) do
    local entry = { id = tostring(try(function() return el.id end)), props = properties(el), subs = {} }
    local subs = try(function() return el.subElements end)
    if type(subs) == "table" then
      for sk, sub in pairs(subs) do entry.subs[tostring(sk)] = properties(sub) end
    end
    out[tostring(k)] = entry
  end
  return out
end

probe.run("s3_element_tables", function(p)
  local tables0 = DoApp.DoApp().currentScore.flows[1].elementTables
  p:fact("barDivisionElements", walk(tables0.barDivisions))
  p:fact("dynamicElements", walk(tables0.dynamics))
  local app = DoApp.DoApp()
  local flow = app.currentScore.flows[1]
  local tables = try(function() return flow.elementTables end)
  p:fact("tables", describe(tables, MEMBERS))
  for _, which in ipairs({ "barDivisions", "tonalityDivisions", "dynamics" }) do
    local t = try(function() return tables[which] end)
    p:fact(which, describe(t, MEMBERS))
    local entries = {}
    for i = 0, 3 do
      local e = try(function() return t[i] end)
      if e ~= nil and type(e) ~= "string" then entries[tostring(i)] = describe(e, MEMBERS) end
    end
    local ok, iter = pcall(ipairs, t)
    if ok then
      for i, e in iter, t, 0 do
        if i > 4 then break end
        entries["ipairs " .. i] = describe(e, MEMBERS)
      end
    end
    p:fact(which .. "Entries", entries)
  end
end)
