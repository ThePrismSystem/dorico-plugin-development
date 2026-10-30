-- Spike: how Dorico stores a pickup bar. On an import of fixtures/pickup.musicxml (a one-beat anacrusis in 4/4), reads
-- a saved copy and reports every bar division with its whole element, and where the notes sit.
--   python tools/run_lua.py spikes/pickup.lua --open fixtures/pickup.musicxml
local here = debug.getinfo(1, "S").source:match("^@(.*[/\\])")
local repo = here .. "../"
local mine = here .. "lib/?.lua;" .. repo .. "lib/?.lua"
for name in pairs(package.loaded) do
  if name:match("^scorereader") or package.searchpath(name, mine) then package.loaded[name] = nil end
end
if not package.path:find(mine, 1, true) then package.path = mine .. ";" .. package.path end
local probe = require("probe")

probe.run("pickup", function(p)
  local savedcopy = require("scorereader.dorico.savedcopy")
  local tree = require("scorereader.tree")
  local values = require("scorereader.values")
  local s = savedcopy.read(DoApp.DoApp(), { dir = probe.runDir })
  local t = s.tree
  local function show(n, depth, out)
    local v = tree.value(t, n)
    out[#out + 1] = string.rep("  ", depth) .. tree.name(t, n) .. ((v and v ~= "") and (" = " .. v) or "")
    for _, c in ipairs(tree.children(t, n)) do show(c, depth + 1, out) end
    return out
  end
  local flow = s.flows[1]
  local divisions = {}
  for _, e in ipairs(flow.events) do
    if e.kind == "timeSignature" then
      local id = tree.value(t, tree.path(t, e.node, "barDivisionElementID"))
      local el = (flow.elements.BarDivisionElementTableDefinition or {})[tonumber(id)]
      divisions[#divisions + 1] = { pos = values.positionText(e.position), numerator = e.numerator,
        event = show(e.node, 0, {}), element = el and show(el, 0, {}) or "none" }
    end
  end
  p:fact("divisions", divisions)
  local notes = {}
  for _, e in ipairs(flow.events) do
    if e.kind == "note" then notes[#notes + 1] = values.positionText(e.position) .. " " .. e.spelling end
  end
  p:fact("notes", notes)
  p:check("found a division", #divisions > 0)
end)
