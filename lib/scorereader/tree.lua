-- A decoded score, whichever encoding it came from (scorereader.dtn, scorereader.xml). Node 0 is the root. A tree is
-- a table of parallel arrays indexed by node id:
--   names, values      the strings; nameOf[id] and valueOf[id] index them from 0
--   kidsOf[id]         the child ids, in order (absent for a leaf)
--   arrayOf[id]        true when the node's children are a list
--   nameIndex[name]    the index of a name in names, for fast lookups
local tree = {}

local NONE = {}

function tree.name(t, id)
  return t.names[t.nameOf[id] + 1]
end

function tree.value(t, id)
  return t.values[t.valueOf[id] + 1]
end

function tree.children(t, id)
  return t.kidsOf[id] or NONE
end

function tree.isArray(t, id)
  return t.arrayOf[id] == true
end

-- The first child of id named name, or nil.
function tree.child(t, id, name)
  local want = t.nameIndex[name]
  if not want then return nil end
  for _, k in ipairs(t.kidsOf[id] or NONE) do
    if t.nameOf[k] == want then return k end
  end
  return nil
end

-- The node reached from id by child names separated by "/", taking the first child of each name, or nil.
function tree.path(t, id, path)
  for step in path:gmatch("[^/]+") do
    id = tree.child(t, id, step)
    if not id then return nil end
  end
  return id
end

-- Every node named name, in id order (parents before their children).
function tree.each(t, name)
  local want, id = t.nameIndex[name], -1
  return function()
    if not want then return nil end
    repeat
      id = id + 1
      if id >= t.count then return nil end
    until t.nameOf[id] == want
    return id
  end
end

return tree
