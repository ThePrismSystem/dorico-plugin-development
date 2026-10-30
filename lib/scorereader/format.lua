-- Which format a decoded score is in. Dorico writes a new fileVersion with every release, patch releases included,
-- so the number is only a label: a format is the structure the readers rely on, and a profile lists the checks for
-- it. A file is read with the first profile it fits and refused only when it fits none, so a Dorico update that
-- leaves that structure alone breaks nothing.
local tree = require("scorereader.tree")

local format = {}

local function rootNamed(name)
  return function(t)
    local got = tree.name(t, 0)
    if got ~= name then return false, "the root is " .. got .. ", not " .. name end
    return true
  end
end

local function rootHas(paths)
  return function(t)
    for _, p in ipairs(paths) do
      if not tree.path(t, 0, p) then return false, "the root has no " .. p end
    end
    return true
  end
end

-- What scorereader.score needs at the root and in every flow.
local ROOT_PARTS = { "fileVersion", "info", "library/instruments/entities", "flows/array", "scorePlayers/array",
  "layouts/array" }
local FLOW_PARTS = { "flowID", "flowName", "flowInfo", "flowPlayers/array", "eventStreams/array", "blocks/array",
  "blockInstances/array", "elementTables/array" }

local function flowsHave(paths)
  return function(t)
    local array = tree.path(t, 0, "flows/array")
    if not array then return false, "the root has no flows/array" end
    for _, flow in ipairs(tree.children(t, array)) do
      for _, p in ipairs(paths) do
        if not tree.path(t, flow, p) then return false, "a flow has no " .. p end
      end
    end
    return true
  end
end

-- Newest first. A reader that relies on a path adds a check for it here; deeper paths (a block's events, a player's
-- instruments) are checked by the readers as they go.
format.PROFILES = {
  {
    name = "dorico6",
    fileVersions = { "1.1392", "1.1412", "1.1416", "1.1417", "1.1444", "1.1450", "1.1452" },
    checks = { rootNamed("kScore"), rootHas(ROOT_PARTS), flowsHave(FLOW_PARTS) },
  },
}

local function fits(profile, t)
  for _, check in ipairs(profile.checks) do
    local ok, why = check(t)
    if not ok then return false, why end
  end
  return true
end

local function lists(profile, fileVersion)
  for _, v in ipairs(profile.fileVersions) do
    if v == fileVersion then return true end
  end
  return false
end

-- {fileVersion, lastSavedVersion, profile, known}; known says whether a profile lists this fileVersion.
function format.detect(t)
  local versionNode = tree.child(t, 0, "fileVersion")
  if not versionNode then error("scorereader: this project has no fileVersion, so it isn't a Dorico score", 0) end
  local fileVersion = tree.value(t, versionNode)
  local savedNode = tree.path(t, 0, "info/lastSavedVersion")
  local lastSavedVersion = savedNode and tree.value(t, savedNode) or "an unknown version"

  local order, firstWhy = {}, nil
  for _, p in ipairs(format.PROFILES) do
    if lists(p, fileVersion) then table.insert(order, 1, p) else order[#order + 1] = p end
  end
  for _, p in ipairs(order) do
    local ok, why = fits(p, t)
    if ok then
      return { fileVersion = fileVersion, lastSavedVersion = lastSavedVersion, profile = p, known = lists(p, fileVersion) }
    end
    firstWhy = firstWhy or why
  end
  error("scorereader: this project's format isn't one the reader knows (fileVersion " .. fileVersion
    .. ", saved by Dorico " .. lastSavedVersion .. "): " .. tostring(firstWhy), 0)
end

return format
