-- The value forms a saved score uses, each as docs/file-format.md lists it, and what reading a wrong one says.
local values = require("scorereader.values")

local function errorOf(fn)
  local ok, err = pcall(fn)
  return not ok and tostring(err) or nil
end

local function fails(t, fn, label)
  local err = errorOf(fn)
  t:ok(err and err:find("^values: cannot read "), label .. ": " .. tostring(err))
end

return {
  positions_and_durations = function(t)
    local p = values.position("13/2")
    t:eq(p.num, 13)
    t:eq(p.den, 2)
    t:eq(values.toNumber(p), 6.5)
    t:eq(values.position("4").den, 1)
    t:eq(values.position("-89/8").num, -89)
    t:eq(values.positionText(values.position("13/3")), "13/3")
    t:eq(values.positionText(values.position("16")), "16")
  end,
  adding_positions_stays_exact = function(t)
    t:eq(values.positionText(values.add(values.position("13/3"), values.position("1/3"))), "14/3")
    t:eq(values.positionText(values.add(values.position("2/3"), values.position("1/3"))), "1")
    t:eq(values.positionText(values.add(values.position("16"), values.position("-1/2"))), "31/2")
  end,
  a_position_that_is_not_one = function(t)
    fails(t, function() return values.position("1.5") end, "decimal")
    fails(t, function() return values.position("") end, "empty")
    fails(t, function() return values.position("1/0") end, "zero denominator")
  end,
  numbers = function(t)
    t:eq(values.number("1586"), 1586)
    t:eq(values.number("-1"), -1)
    t:eq(values.number("0.000000"), 0)
    fails(t, function() return values.number("kAbove") end, "an enum")
  end,
  bools = function(t)
    t:eq(values.bool("true"), true)
    t:eq(values.bool("false"), false)
    fails(t, function() return values.bool("yes") end, "yes")
  end,
  typed_scalars = function(t)
    t:eq(values.typed('string: "noteheadset.rectangular"').value, "noteheadset.rectangular")
    t:eq(values.typed('string: "C"').kind, "string")
    t:eq(values.typed('string: ""').value, "")
    t:eq(values.typed("int: 4").value, 4)
    t:eq(values.typed("double: 0.2").value, 0.2)
    t:eq(values.typed("bool: true").value, true)
    t:eq(values.typed("null: ").kind, "null")
    t:eq(values.string('string: "#ff00a050"'), "#ff00a050")
  end,
  a_plain_value_is_not_typed = function(t)
    fails(t, function() return values.typed("tri:") end, "a lyric syllable ending in a colon")
    fails(t, function() return values.typed("C:/Users/x.musicxml") end, "a path")
    fails(t, function() return values.string("C") end, "a bare string")
    fails(t, function() return values.typed('string: "unclosed') end, "an unclosed string")
  end,
  a_context_layout_list = function(t)
    local items = values.list("steamVariantList:list: {int: 1}, {int: -1}, {bool: false}")
    t:eq(#items, 3)
    t:eq(items[1].kind, "int")
    t:eq(items[1].value, 1)
    t:eq(items[2].value, -1)
    t:eq(items[3].value, false)
  end,
  nested_and_empty_items = function(t)
    local items = values.list("steamVariantList:list: {int: 3}, {int: 2}, {list: {int: 7}, {int: 0}}, {bool: true}")
    t:eq(#items, 4)
    t:eq(items[3].kind, "list")
    t:eq(items[3].value[1].value, 7)
    t:eq(items[3].value[2].value, 0)
    local dyn = values.list("steamVariantList:list: {int: 0}, {}, {bool: true}, {}")
    t:eq(#dyn, 4)
    t:eq(dyn[2].kind, "empty")
    t:eq(dyn[4].kind, "empty")
    t:eq(#values.list("steamVariantList:list: "), 0, "an empty list")
    local s = values.list('steamVariantList:list: {int: 15}, {string: "kIntervalMajorOrPerfect"}')
    t:eq(s[2].value, "kIntervalMajorOrPerfect")
  end,
  a_typed_list_value = function(t)
    local v = values.typed("list: {int: 8}, {int: 0}")
    t:eq(v.kind, "list")
    t:eq(v.value[1].value, 8)
  end,
  a_broken_list = function(t)
    fails(t, function() return values.list("steamVariantList:list: {int: 1") end, "unclosed")
    fails(t, function() return values.list("steamVariantList:list: {frog: 1}") end, "unknown kind")
    fails(t, function() return values.list("list: {int: 1}") end, "not a steamVariantList")
  end,
}
