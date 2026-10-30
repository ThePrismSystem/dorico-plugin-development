-- Spike F1: what saved scores hold. Runs on stock Lua 5.2, outside Dorico:
--   lua52 spikes/f1_catalogue.lua <out.json> <project.dorico>...
-- For every node path (names joined by "/", a list node marked "*") it counts the nodes, classifies their values
-- and keeps an example, per fileVersion. It also lists every kind of event definition with the fields it has. The
-- JSON is the raw map docs/file-format.md is written from.
local here = debug.getinfo(1, "S").source:match("^@(.*[/\\])") or "./"
local mine = here .. "../lib/?.lua;" .. here .. "lib/?.lua"
if not package.path:find(mine, 1, true) then package.path = mine .. ";" .. package.path end
local project = require("scorereader.project")
local format = require("scorereader.format")
local tree = require("scorereader.tree")
local json = require("json")

-- The form of a value: its type prefix when it has one ("string:", "steamVariantList:"), else its shape.
local function form(v)
  if v == "" then return "empty" end
  if v:match("^%-?%d+$") then return "integer" end
  if v:match("^%-?%d+/%d+$") then return "fraction" end
  if v:match("^%-?%d+%.%d+$") then return "decimal" end
  if v == "true" or v == "false" then return "bool" end
  local prefix = v:match("^([%a][%w]*):")
  if prefix then return prefix .. ":" end
  if v:match("^k%u[%w]*$") then return "enum" end
  return "text"
end

local function add(map, key) map[key] = (map[key] or 0) + 1 end

local paths, events, files = {}, {}, {}

local function walk(t, fileVersion)
  local stack = { { 0, tree.name(t, 0) } }
  while #stack > 0 do
    local id, path = table.unpack(table.remove(stack))
    local p = paths[path]
    if not p then
      p = { count = 0, forms = {}, versions = {} }
      paths[path] = p
    end
    p.count = p.count + 1
    p.versions[fileVersion] = true
    local kids = tree.children(t, id)
    if #kids == 0 then
      local v = tree.value(t, id)
      local f = form(v)
      add(p.forms, f)
      if not p.example and v ~= "" then p.example = #v > 120 and v:sub(1, 117) .. "..." or v end
    end
    local name = tree.name(t, id)
    if name:match("EventDefinition$") then
      local e = events[name]
      if not e then
        e = { count = 0, fields = {}, versions = {} }
        events[name] = e
      end
      e.count = e.count + 1
      e.versions[fileVersion] = true
      for _, k in ipairs(kids) do add(e.fields, tree.name(t, k)) end
    end
    for i = #kids, 1, -1 do
      local k = kids[i]
      stack[#stack + 1] = { k, path .. "/" .. tree.name(t, k) .. (tree.isArray(t, k) and "*" or "") }
    end
  end
end

for i = 2, #arg do
  local t0 = os.clock()
  local p = project.readFile(arg[i])
  local f = format.detect(p.tree)
  walk(p.tree, f.fileVersion)
  files[#files + 1] = { file = arg[i]:match("[^/\\]+$"), fileVersion = f.fileVersion, savedBy = f.lastSavedVersion,
    encoding = p.encoding, nodes = p.tree.count }
  io.stderr:write(string.format("%-50s %s %s %.1fs\n", files[#files].file, f.fileVersion, p.encoding, os.clock() - t0))
end

local function keys(set)
  local out = {}
  for k in pairs(set) do out[#out + 1] = k end
  table.sort(out)
  return out
end

for _, p in pairs(paths) do p.versions = keys(p.versions) end
for _, e in pairs(events) do e.versions = keys(e.versions) end
local out = assert(io.open(arg[1], "wb"))
out:write(json.encode({ files = files, paths = paths, events = events }))
out:close()
