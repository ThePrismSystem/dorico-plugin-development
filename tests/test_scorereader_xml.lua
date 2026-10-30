-- score.xml, the encoding Steinberg's shipped examples use: the same tree as score.dtn, written as XML.
local xml = require("scorereader.xml")
local tree = require("scorereader.tree")
local project = require("scorereader.project")
local score = require("scorereader.score")
local values = require("scorereader.values")

local function errorOf(fn)
  local ok, err = pcall(fn)
  return not ok and tostring(err) or nil
end

local function fails(t, text, label)
  local err = errorOf(function() return xml.decode(text) end)
  t:ok(err and err:find("xml: ", 1, true), label .. ": " .. tostring(err))
end

local ESCAPES = { ["&"] = "&amp;", ["<"] = "&lt;", [">"] = "&gt;", ['"'] = "&quot;" }

-- A decoded tree written back as score.xml would hold it.
local function toXml(t)
  local out = { '<?xml version="1.0" encoding="utf-8"?>\n' }
  local function write(id)
    local name, kids = tree.name(t, id), tree.children(t, id)
    local open = "<" .. name .. (tree.isArray(t, id) and ' array="true"' or "")
    local v = tree.value(t, id)
    if #kids > 0 then
      assert(v == "", name .. " #" .. id .. " has children and a value, which XML can't hold")
      out[#out + 1] = open .. ">"
      for _, k in ipairs(kids) do write(k) end
      out[#out + 1] = "</" .. name .. ">"
    elseif v == "" then
      out[#out + 1] = open .. "/>"
    else
      out[#out + 1] = open .. ">" .. v:gsub('[&<>"]', ESCAPES) .. "</" .. name .. ">"
    end
  end
  write(0)
  return table.concat(out)
end

-- Where a and b differ, leaving out node ids, which depend on the order the encoding lists nodes, and the tree and
-- cache; nil when they don't.
local SKIP = { node = true, tree = true, cache = true }
local function difference(a, b, path, seen)
  if type(a) ~= "table" or type(b) ~= "table" then
    if a ~= b then return path .. ": " .. tostring(a) .. " vs " .. tostring(b) end
    return nil
  end
  if seen[a] then return nil end
  seen[a] = true
  for k, v in pairs(a) do
    if not SKIP[k] then
      local d = difference(v, b[k], path .. "." .. tostring(k), seen)
      if d then return d end
    end
  end
  for k in pairs(b) do
    if not SKIP[k] and a[k] == nil then return path .. "." .. tostring(k) .. ": only in the second" end
  end
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
  an_empty_list_with_indentation_has_no_value = function(t)
    local s = xml.decode('<a>\n\t<b array="true">\n\t</b>\n</a>')
    t:eq(tree.value(s, tree.child(s, 0, "b")), "", "as score.dtn gives a list node")
    t:eq(tree.value(xml.decode("<a><b> </b></a>"), 1), " ", "a leaf keeps its spaces")
  end,
  a_score_reads_the_same_from_either_encoding = function(t)
    local here = debug.getinfo(1, "S").source:match("^@(.*[/\\])") or "./"
    local dtnTree = project.readFile(here .. "../fixtures/6.2.30/reading.dorico").tree
    local fromDtn = score.read(dtnTree)
    local fromXml = score.read(xml.decode(toXml(dtnTree)))
    t:eq(fromXml.tree.encoding, "xml")
    t:ok(#fromDtn.flows[1].events > 100, "a score with events in it")
    t:eq(difference(fromDtn, fromXml, "score", {}), nil)
    local e = fromXml.flows[1].events[1]
    e.position = values.add(e.position, values.position("1"))
    t:ok(difference(fromDtn, fromXml, "score", {}), "a moved event shows")
  end,
  a_reference_with_no_hash = function(t) fails(t, "<a>&x41;</a>", "&x41;") end,
  an_ampersand_that_starts_no_reference = function(t)
    fails(t, "<a>A & B</a>", "bare &")
    fails(t, "<a>A &amp B</a>", "no semicolon")
  end,
  attributes_in_another_form = function(t)
    fails(t, "<a array='true'/>", "single quotes")
    fails(t, "<a array>1</a>", "no value")
  end,
  mismatched_close_tag = function(t) fails(t, "<a><b>x</c></a>", "mismatched") end,
  unclosed_element = function(t) fails(t, "<a><b>x</b>", "unclosed") end,
  text_beside_elements = function(t) fails(t, "<a>words<b>x</b></a>", "mixed content") end,
  unknown_entity = function(t) fails(t, "<a>&nbsp;</a>", "entity") end,
  unknown_attribute = function(t) fails(t, '<a kind="x">1</a>', "attribute") end,
  two_roots = function(t) fails(t, "<a>1</a><b>2</b>", "second root") end,
}
