-- Spike F1, second part: the paths that every parent node has in some fileVersions and none has in others, which
-- are format changes rather than content a project happened not to use. Runs on stock Lua 5.2, outside Dorico:
--   lua52 spikes/f1_changes.lua <project.dorico>...
local here = debug.getinfo(1, "S").source:match("^@(.*[/\\])") or "./"
local mine = here .. "../lib/?.lua;" .. here .. "lib/?.lua"
if not package.path:find(mine, 1, true) then package.path = mine .. ";" .. package.path end
local project = require("scorereader.project")
local format = require("scorereader.format")
local tree = require("scorereader.tree")

-- counts[version][path] = nodes; a child path's count compared with its parent's
local counts = {}
for i = 1, #arg do
  local p = project.readFile(arg[i])
  local v = format.detect(p.tree).fileVersion
  local c = counts[v] or {}
  counts[v] = c
  local stack = { { 0, tree.name(p.tree, 0) } }
  while #stack > 0 do
    local id, path = table.unpack(table.remove(stack))
    c[path] = (c[path] or 0) + 1
    for _, k in ipairs(tree.children(p.tree, id)) do
      stack[#stack + 1] = { k, path .. "/" .. tree.name(p.tree, k) .. (tree.isArray(p.tree, k) and "*" or "") }
    end
  end
end

local versions, all = {}, {}
for v, c in pairs(counts) do
  versions[#versions + 1] = v
  for path in pairs(c) do all[path] = true end
end
table.sort(versions)
local list = {}
for path in pairs(all) do list[#list + 1] = path end
table.sort(list)
for _, path in ipairs(list) do
  local parent = path:match("^(.*)/[^/]+$")
  if parent then
    local always, never = {}, {}
    for _, v in ipairs(versions) do
      local pc, cc = counts[v][parent] or 0, counts[v][path] or 0
      if pc > 0 and cc == 0 then never[#never + 1] = v end
      if pc > 0 and cc >= pc then always[#always + 1] = v end
    end
    -- a change: some versions have it on every parent, others on none, and none in between
    if #always > 0 and #never > 0 and #always + #never == #versions then
      local parentChanged = false
      local grand = parent:match("^(.*)/[^/]+$")
      if grand then
        for _, v in ipairs(versions) do
          if (counts[v][grand] or 0) > 0 and (counts[v][parent] or 0) == 0 then parentChanged = true end
        end
      end
      if not parentChanged then
        print(path, "has:" .. table.concat(always, ","), "lacks:" .. table.concat(never, ","))
      end
    end
  end
end
