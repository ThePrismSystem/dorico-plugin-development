-- score.xml, the encoding Steinberg's shipped examples use: the same tree as score.dtn, written as XML.
local xml = require("scorereader.xml")
local tree = require("scorereader.tree")

local function errorOf(fn)
  local ok, err = pcall(fn)
  return not ok and tostring(err) or nil
end

local function fails(t, text, label)
  local err = errorOf(function() return xml.decode(text) end)
  t:ok(err and err:find("xml: ", 1, true), label .. ": " .. tostring(err))
end

local SCORE = '<?xml version="1.0" encoding="utf-8"?>\n<kScore>\n\t<fileVersion>1.1412</fileVersion>\n'
  .. '\t<info>\n\t\t<title>Zo&#235; &amp; co</title>\n\t\t<subtitle/>\n\t\t<composer></composer>\n\t</info>\n'
  .. '\t<entries array="true">\n\t\t<entry>\n\t\t\t<value>string: &quot;G&quot;</value>\n\t\t</entry>\n'
  .. '\t\t<entry>\n\t\t\t<value>steamVariantList:list: {int: -1}, {bool: false}</value>\n\t\t</entry>\n'
  .. '\t</entries>\n\t<empty array="true"/>\n</kScore>\n'

return {
  root_and_encoding = function(t)
    local s = xml.decode(SCORE)
    t:eq(tree.name(s, 0), "kScore")
    t:eq(s.encoding, "xml")
    t:eq(tree.value(s, tree.child(s, 0, "fileVersion")), "1.1412")
  end,
  entities_become_utf8 = function(t)
    local s = xml.decode(SCORE)
    t:eq(tree.value(s, tree.path(s, 0, "info/title")), "Zo\195\171 & co")
  end,
  quotes_in_a_value = function(t)
    local s = xml.decode(SCORE)
    local first = tree.children(s, tree.child(s, 0, "entries"))[1]
    t:eq(tree.value(s, tree.child(s, first, "value")), 'string: "G"')
  end,
  a_value_keeps_its_spaces = function(t)
    local s = xml.decode(SCORE)
    local second = tree.children(s, tree.child(s, 0, "entries"))[2]
    t:eq(tree.value(s, tree.child(s, second, "value")), "steamVariantList:list: {int: -1}, {bool: false}")
  end,
  empty_elements_are_empty_leaves = function(t)
    local s = xml.decode(SCORE)
    t:eq(tree.value(s, tree.path(s, 0, "info/subtitle")), "")
    t:eq(tree.value(s, tree.path(s, 0, "info/composer")), "")
    t:eq(#tree.children(s, tree.path(s, 0, "info/subtitle")), 0)
  end,
  the_array_attribute = function(t)
    local s = xml.decode(SCORE)
    t:eq(tree.isArray(s, tree.child(s, 0, "entries")), true)
    t:eq(tree.isArray(s, tree.child(s, 0, "empty")), true, "a self-closed list")
    t:eq(tree.isArray(s, tree.child(s, 0, "info")), false)
    t:eq(#tree.children(s, tree.child(s, 0, "entries")), 2)
  end,
  ids_run_parents_first = function(t)
    local s = xml.decode(SCORE)
    t:eq(tree.child(s, 0, "fileVersion"), 1)
    t:eq(tree.child(s, 0, "info"), 2)
    t:eq(tree.path(s, 0, "info/title"), 3)
  end,
  hex_and_four_byte_characters = function(t)
    local s = xml.decode("<a><b>1&#x2032; &#x1D11E;</b></a>")
    t:eq(tree.value(s, tree.child(s, 0, "b")), "1\226\128\178 \240\157\132\158")
  end,
  each_finds_elements_by_name = function(t)
    local n = 0
    for _ in tree.each(xml.decode(SCORE), "entry") do n = n + 1 end
    t:eq(n, 2)
  end,
  mismatched_close_tag = function(t) fails(t, "<a><b>x</c></a>", "mismatched") end,
  unclosed_element = function(t) fails(t, "<a><b>x</b>", "unclosed") end,
  text_beside_elements = function(t) fails(t, "<a>words<b>x</b></a>", "mixed content") end,
  unknown_entity = function(t) fails(t, "<a>&nbsp;</a>", "entity") end,
  unknown_attribute = function(t) fails(t, '<a kind="x">1</a>', "attribute") end,
  two_roots = function(t) fails(t, "<a>1</a><b>2</b>", "second root") end,
}
