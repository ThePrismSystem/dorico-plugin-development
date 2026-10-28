-- The test runner's own assertions, so a broken t:eq or t:fails can't make every other test pass.
return {
  eq_accepts_equal_values = function(t)
    t:eq(1 + 1, 2)
    t:eq("a" .. "b", "ab")
  end,
  eq_rejects_different_values = function(t)
    t:fails(function() t:eq(1, 2) end)
  end,
  ok_rejects_false = function(t)
    t:fails(function() t:ok(false) end)
    t:ok(true)
  end,
  fails_rejects_a_function_that_succeeds = function(t)
    local ok = pcall(function() t:fails(function() end) end)
    t:eq(ok, false, "t:fails must raise when nothing failed")
  end,
}
