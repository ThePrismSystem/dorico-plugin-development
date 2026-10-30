-- Writes a saved project's score as indented text, one node per line: "name* = 'value'  #id", where * marks a
-- list. Runs on stock Lua 5.2, outside Dorico:
--   lua52 spikes/tree_dump.lua <project.dorico> [path] > out.txt
-- path starts the dump at a node below the root, child names separated by "/", taking the first child of each
-- name, or the nth with name[n]: flows/array/flow[2]/elementTables.
local here = debug.getinfo(1, "S").source:match("^@(.*[/\\])") or "./"
local mine = here .. "../lib/?.lua"
if not package.path:find(mine, 1, true) then package.path = mine .. ";" .. package.path end
local project = require("scorereader.project")
local tree = require("scorereader.tree")

local t = project.readFile(assert(arg[1], "usage: lua52 spikes/tree_dump.lua <project.dorico> [path]")).tree
local start = 0
for step in (arg[2] or ""):gmatch("[^/]+") do
  local name, nth = step:match("^(.-)%[(%d+)%]$")
  name, nth = name or step, tonumber(nth) or 1
  local found
  for _, k in ipairs(tree.children(t, start)) do
    if tree.name(t, k) == name then
      nth = nth - 1
      if nth == 0 then found = k break end
    end
  end
  start = assert(found, "no " .. step .. " below node " .. start)
end

local out = {}
local stack = { { start, 0 } }
while #stack > 0 do
  local id, depth = table.unpack(table.remove(stack))
  local v = tree.value(t, id)
  out[#out + 1] = string.rep("  ", depth) .. tree.name(t, id) .. (tree.isArray(t, id) and "*" or "")
    .. (v ~= "" and (" = '" .. v .. "'") or "") .. "  #" .. id
  local kids = tree.children(t, id)
  for i = #kids, 1, -1 do stack[#stack + 1] = { kids[i], depth + 1 } end
end
io.write(table.concat(out, "\n"), "\n")
