-- The binary tree Dorico saves a project's score in (score.dtn): lib/scorereader/dtn.lua describes the layout.
local dtn = require("scorereader.dtn")
local tree = require("scorereader.tree")
local zip = require("scorereader.zip")

local here = debug.getinfo(1, "S").source:match("^@(.*[/\\])") or "./"
local build = require("dtn_build")
local encode = build.encode

-- root "a" holding leaf "b" = "x"; the root's tag has the high nibble 0x1, the leaf's 0x2, as two saves wrote them
local TINY = encode({ "a", "b" }, { "", "x" }, { { 0x12, 0, 0, { 1 } }, { 0x20, 1, 1 } })

local function errorOf(fn)
  local ok, err = pcall(fn)
  return not ok and tostring(err) or nil
end

-- reason: what the error must say after "dtn: ", when that is pinned
local function fails(t, bytes, label, reason)
  local err = errorOf(function() return dtn.decode(bytes) end)
  t:ok(err and err:find("dtn: " .. (reason or ""), 1, true), label .. ": " .. tostring(err))
end

return {
  tiny_tree = function(t)
    local t2 = dtn.decode(TINY)
    t:eq(tree.name(t2, 0), "a")
    local b = tree.child(t2, 0, "b")
    t:eq(b, 1, "the leaf")
    t:eq(tree.value(t2, b), "x")
    t:eq(#tree.children(t2, 0), 1, "one child")
    t:eq(#tree.children(t2, 1), 0, "a leaf has none")
    t:eq(tree.child(t2, 0, "c"), nil, "no such child")
  end,
  records_the_array_flag = function(t)
    local t2 = dtn.decode(build.tree({ "root", nil, { { "entries", nil, {}, true }, { "plain", "1" } } }))
    t:eq(tree.isArray(t2, tree.child(t2, 0, "entries")), true, "a tag with the 1 bit")
    t:eq(tree.isArray(t2, tree.child(t2, 0, "plain")), false, "a tag without it")
  end,
  the_tags_other_bits_are_ignored = function(t)
    -- saved files use every tag byte from 0x00 to 0xFF
    local t2 = dtn.decode(encode({ "a", "b", "c" }, { "" },
      { { 0xFE, 0, 0, { 1, 2 } }, { 0xFD, 1, 0 }, { 0xFC, 2, 0 } }))
    t:eq(#tree.children(t2, 0), 2, "0xFE has children")
    t:eq(tree.isArray(t2, 1), true, "0xFD is a list")
    t:eq(#tree.children(t2, 2), 0, "0xFC is a leaf")
    t:eq(tree.isArray(t2, 2), false)
  end,
  trailing_bytes = function(t) fails(t, TINY .. "\0", "trailing") end,
  truncated = function(t) fails(t, TINY:sub(1, -2), "truncated") end,
  bad_header = function(t) fails(t, "\5" .. TINY:sub(2), "header") end,
  child_out_of_range = function(t)
    fails(t, encode({ "a" }, { "" }, { { 0x22, 0, 0, { 7 } } }), "child 7 of 1 node")
  end,
  name_out_of_range = function(t)
    fails(t, encode({ "a" }, { "" }, { { 0x20, 5, 0 } }), "name 5 of 1", "node 0 names an entry out of range")
  end,
  value_out_of_range = function(t)
    fails(t, encode({ "a" }, { "" }, { { 0x20, 0, 3 } }), "value 3 of 1", "node 0 names an entry out of range")
  end,
  a_name_with_no_end = function(t)
    fails(t, "\4\0\0\0\1\0\0\0\1\0\0\0abc", "no NUL", "input ends early")
  end,
  second_header_word = function(t) fails(t, TINY:sub(1, 4) .. "\2" .. TINY:sub(6), "2", "not a saved score") end,
  too_short = function(t) fails(t, TINY:sub(1, 8), "8 bytes", "not a saved score") end,
  fixture = function(t)
    local f = assert(io.open(here .. "../fixtures/6.2.30/sample.dorico", "rb"))
    local bytes = f:read("*a")
    f:close()
    local t2 = dtn.decode(zip.entry(bytes, "score.dtn"))
    t:eq(tree.name(t2, 0), "kScore")
    t:eq(t2.encoding, "dtn")
  end,
}
