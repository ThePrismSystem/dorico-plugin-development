-- Walking a decoded tree: the accessors every reader uses, the same for both encodings.
local tree = require("scorereader.tree")
local dtn = require("scorereader.dtn")
local build = require("dtn_build")

local T = dtn.decode(build.tree({ "kScore", nil, {
  { "info", nil, { { "title", "Sample" }, { "composer", "" } } },
  { "flows", nil, { { "flow", nil, { { "flowID", "0" } } }, { "flow", nil, { { "flowID", "1" } } } }, true },
} }))

return {
  path_finds_a_nested_node = function(t)
    t:eq(tree.value(T, tree.path(T, 0, "info/title")), "Sample")
  end,
  path_is_nil_for_a_missing_step = function(t)
    t:eq(tree.path(T, 0, "info/subtitle"), nil)
    t:eq(tree.path(T, 0, "nothing/title"), nil)
  end,
  path_from_a_child = function(t)
    local info = tree.child(T, 0, "info")
    t:eq(tree.value(T, tree.path(T, info, "composer")), "")
  end,
  each_visits_every_node_of_a_name = function(t)
    local ids = {}
    for id in tree.each(T, "flowID") do ids[#ids + 1] = tree.value(T, id) end
    t:eq(table.concat(ids, ","), "0,1")
  end,
  each_of_an_unknown_name_visits_nothing = function(t)
    local n = 0
    for _ in tree.each(T, "nope") do n = n + 1 end
    t:eq(n, 0)
  end,
}
