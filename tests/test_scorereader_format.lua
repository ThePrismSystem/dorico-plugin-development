-- Detecting the format. The fileVersion is only a label (Dorico changes it every release); a file is refused only when
-- its structure fits no known profile.
local format = require("scorereader.format")
local project = require("scorereader.project")
local tree = require("scorereader.tree")
local xml = require("scorereader.xml")
local json = require("json")

local here = debug.getinfo(1, "S").source:match("^@(.*[/\\])") or "./"
local fixtures = here .. "../fixtures/"

local function manifest()
  local f = assert(io.open(fixtures .. "versions.json", "rb"))
  local list = json.decode(f:read("*a"))
  f:close()
  return list
end

local function errorOf(fn)
  local ok, err = pcall(fn)
  return not ok and tostring(err) or nil
end

-- A copy of t with node id's value (or name) replaced; the decoded tables are shared, so the copy gets its own.
local function withValue(t, id, value)
  local copy = setmetatable({ values = { table.unpack(t.values) }, valueOf = setmetatable({}, { __index = t.valueOf }) },
    { __index = t })
  copy.values[#copy.values + 1] = value
  copy.valueOf[id] = #copy.values - 1
  return copy
end

local function withName(t, id, name)
  local copy = setmetatable({ names = { table.unpack(t.names) }, nameOf = setmetatable({}, { __index = t.nameOf }),
    nameIndex = setmetatable({}, { __index = t.nameIndex }) }, { __index = t })
  copy.names[#copy.names + 1] = name
  copy.nameOf[id] = #copy.names - 1
  copy.nameIndex[name] = #copy.names - 1
  return copy
end

local SAMPLE
local function sample()
  SAMPLE = SAMPLE or project.readFile(fixtures .. "6.2.30/sample.dorico").tree
  return SAMPLE
end

local MINIMAL_XML = "<kScore><fileVersion>1.1412</fileVersion><info><lastSavedVersion>6.1.5</lastSavedVersion></info>"
  .. '<library><instruments><entities array="true"/></instruments></library><flows><array array="true"/></flows>'
  .. '<scorePlayers><array array="true"/></scorePlayers><layouts><array array="true"/></layouts></kScore>'

return {
  every_fixture_is_a_known_format = function(t)
    for _, entry in ipairs(manifest()) do
      local found = format.detect(project.readFile(fixtures .. entry.path).tree)
      t:eq(found.fileVersion, entry.fileVersion, entry.path)
      t:eq(found.lastSavedVersion, entry.savedBy, entry.path)
      t:eq(found.known, true, entry.path .. " is listed")
      t:eq(found.profile.name, "dorico6", entry.path)
    end
  end,
  an_xml_score = function(t)
    local found = format.detect(xml.decode(MINIMAL_XML))
    t:eq(found.fileVersion, "1.1412")
    t:eq(found.lastSavedVersion, "6.1.5")
    t:eq(found.known, true)
  end,
  an_unknown_number_with_a_known_structure = function(t)
    local s = sample()
    local found = format.detect(withValue(s, tree.child(s, 0, "fileVersion"), "9.9999"))
    t:eq(found.fileVersion, "9.9999")
    t:eq(found.known, false)
    t:eq(found.profile.name, "dorico6")
  end,
  a_root_the_reader_does_not_know = function(t)
    local s = sample()
    local err = errorOf(function() return format.detect(withName(s, 0, "kNotAScore")) end)
    t:ok(err and err:find("^scorereader: this project's format isn't one the reader knows %(fileVersion 1%.1452, "
      .. "saved by Dorico 6%.2%.30%): "), tostring(err))
  end,
  a_missing_part_is_named = function(t)
    local s = sample()
    local err = errorOf(function() return format.detect(withName(s, tree.child(s, 0, "flows"), "flowz")) end)
    t:ok(err and err:find("flows", 1, true), tostring(err))
  end,
  a_flow_without_what_the_readers_need = function(t)
    local s = sample()
    local blocks = tree.path(s, 0, "flows/array/flow/blocks")
    local err = errorOf(function() return format.detect(withName(s, blocks, "blockz")) end)
    t:ok(err and err:find("a flow has no blocks", 1, true), tostring(err))
  end,
  a_list_the_readers_walk_is_missing = function(t)
    local s = sample()
    local players = tree.path(s, 0, "scorePlayers/array")
    local err = errorOf(function() return format.detect(withName(s, players, "arrayz")) end)
    t:ok(err and err:find("the root has no scorePlayers/array", 1, true), tostring(err))
    local streams = tree.path(s, 0, "flows/array/flow/eventStreams/array")
    err = errorOf(function() return format.detect(withName(s, streams, "arrayz")) end)
    t:ok(err and err:find("a flow has no eventStreams/array", 1, true), tostring(err))
  end,
  no_file_version = function(t)
    local err = errorOf(function() return format.detect(xml.decode("<kScore><info/></kScore>")) end)
    t:ok(err and err:find("^scorereader: .*fileVersion"), tostring(err))
  end,
}
