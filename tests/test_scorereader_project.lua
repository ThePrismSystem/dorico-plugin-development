-- Opening a .dorico: the score is score.dtn in projects Dorico 6.2 saves and score.xml in Steinberg's examples.
local project = require("scorereader.project")
local tree = require("scorereader.tree")
local dtnBuild = require("dtn_build")
local zipBuild = require("zip_build")

local here = debug.getinfo(1, "S").source:match("^@(.*[/\\])") or "./"

local DTN = dtnBuild.tree({ "kScore", nil, { { "fileVersion", "1.1452" } } })
local XML = '<?xml version="1.0" encoding="utf-8"?>\n<kScore>\n\t<fileVersion>1.1412</fileVersion>\n</kScore>\n'

local function errorOf(fn)
  local ok, err = pcall(fn)
  return not ok and tostring(err) or nil
end

return {
  reads_a_binary_score = function(t)
    local p = project.read(zipBuild.archive({ { "META-INF/container.xml", "<container/>" }, { "score.dtn", DTN } }))
    t:eq(p.encoding, "dtn")
    t:eq(tree.name(p.tree, 0), "kScore")
    t:eq(p.entries[2], "score.dtn", "the archive's entries, in order")
  end,
  reads_an_xml_score = function(t)
    local p = project.read(zipBuild.archive({ { "score.xml", XML } }))
    t:eq(p.encoding, "xml")
    t:eq(tree.value(p.tree, tree.child(p.tree, 0, "fileVersion")), "1.1412")
  end,
  prefers_the_binary_score = function(t)
    t:eq(project.read(zipBuild.archive({ { "score.xml", XML }, { "score.dtn", DTN } })).encoding, "dtn")
  end,
  neither_score = function(t)
    local err = errorOf(function() return project.read(zipBuild.archive({ { "readme.txt", "hi" } })) end)
    t:eq(err, "scorereader: not a Dorico project (no score.dtn or score.xml)")
  end,
  a_truncated_score = function(t)
    local err = errorOf(function() return project.read(zipBuild.archive({ { "score.dtn", DTN:sub(1, -3) } })) end)
    t:ok(err and err:find("^dtn: "), tostring(err))
  end,
  not_a_zip = function(t)
    local err = errorOf(function() return project.read("plain text") end)
    t:ok(err and err:find("^zip: "), tostring(err))
  end,
  reads_a_file = function(t)
    local p = project.readFile(here .. "../fixtures/6.2.30/sample.dorico")
    t:eq(p.encoding, "dtn")
    t:eq(tree.name(p.tree, 0), "kScore")
  end,
  a_missing_file = function(t)
    local err = errorOf(function() return project.readFile(here .. "no-such.dorico") end)
    t:ok(err and err:find("^scorereader: cannot read "), tostring(err))
  end,
}
