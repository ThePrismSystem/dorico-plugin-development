-- The forms a node's value takes (docs/file-format.md, "Values"). Plain values are integers, fractions, decimals,
-- bools, enums and text. Property values and contexts are typed: 'string: "C"', 'int: 4', 'double: 0.2',
-- 'bool: true', 'null: ', 'list: {...}, {...}' and 'steamVariantList:list: {...}, ...'. A plain value can look typed
-- (a lyric syllable "tri:", a path "C:/..."), so read a typed form only where one is expected. Each reader raises
-- "values: cannot read <raw> as <form>" on a mismatch.
local values = {}

local find, sub = string.find, string.sub

local LIST = "steamVariantList:list: "

local function fail(raw, form)
  error("values: cannot read '" .. tostring(raw) .. "' as " .. form, 0)
end

local function gcd(a, b)
  a, b = math.abs(a), math.abs(b)
  while b ~= 0 do a, b = b, a % b end
  return a
end

local function lowest(num, den)
  local g = gcd(num, den)
  if g > 1 then num, den = num / g, den / g end
  return { num = num, den = den }
end

-- {num, den} in lowest terms from "13/2" or "4", the form positions and durations take.
function values.position(raw)
  local n, d = tostring(raw):match("^(%-?%d+)/(%d+)$")
  if not n then
    n, d = tostring(raw):match("^(%-?%d+)$"), "1"
  end
  if not n or tonumber(d) == 0 then fail(raw, "a position") end
  return lowest(tonumber(n), tonumber(d))
end

function values.toNumber(p)
  return p.num / p.den
end

-- a + b, exactly, in lowest terms.
function values.add(a, b)
  return lowest(a.num * b.den + b.num * a.den, a.den * b.den)
end

-- Back to the file's own form: "13/3", or "16" for a whole number.
function values.positionText(p)
  return p.den == 1 and tostring(p.num) or (p.num .. "/" .. p.den)
end

function values.number(raw)
  if tostring(raw):match("^%-?%d+%.?%d*$") then return tonumber(raw) end
  fail(raw, "a number")
end

function values.bool(raw)
  if raw == "true" then return true end
  if raw == "false" then return false end
  fail(raw, "a bool")
end

-- Typed values, read from s at i. Each returns the item and the index after it.
local parseItems

local function parseScalar(raw, s, i, kind)
  if kind == "string" then
    if sub(s, i, i) ~= '"' then fail(raw, "a typed value") end
    local close = find(s, '"', i + 1, true)
    if not close then fail(raw, "a typed value") end
    return { kind = "string", value = sub(s, i + 1, close - 1) }, close + 1
  elseif kind == "int" or kind == "double" then
    local num = s:match("^%-?%d+%.?%d*", i)
    if not num then fail(raw, "a typed value") end
    return { kind = kind, value = tonumber(num) }, i + #num
  elseif kind == "bool" then
    if sub(s, i, i + 3) == "true" then return { kind = "bool", value = true }, i + 4 end
    if sub(s, i, i + 4) == "false" then return { kind = "bool", value = false }, i + 5 end
  elseif kind == "null" then
    return { kind = "null" }, i
  elseif kind == "list" then
    local items, j = parseItems(raw, s, i)
    return { kind = "list", value = items }, j
  end
  fail(raw, "a typed value")
end

-- One "{kind: value}" or "{}".
local function parseItem(raw, s, i)
  if sub(s, i, i) ~= "{" then fail(raw, "a list") end
  if sub(s, i + 1, i + 1) == "}" then return { kind = "empty" }, i + 2 end
  local kind = s:match("^(%a+): ", i + 1)
  if not kind then fail(raw, "a list") end
  local item, j = parseScalar(raw, s, i + 1 + #kind + 2, kind)
  if sub(s, j, j) ~= "}" then fail(raw, "a list") end
  return item, j + 1
end

-- Items separated by ", ", up to the end of s or a "}" that closes an outer item.
function parseItems(raw, s, i)
  local items = {}
  while i <= #s and sub(s, i, i) == "{" do
    local item
    item, i = parseItem(raw, s, i)
    items[#items + 1] = item
    if sub(s, i, i + 1) == ", " and sub(s, i + 2, i + 2) == "{" then i = i + 2 end
  end
  return items, i
end

-- {kind, value} for a typed value; kind is string, int, double, bool, null or list (value: the items).
function values.typed(raw)
  local s = tostring(raw)
  if sub(s, 1, #LIST) == LIST then return { kind = "list", value = values.list(raw) } end
  local kind = s:match("^(%a+): ")
  if not kind then
    if s == "null: " then return { kind = "null" } end
    fail(raw, "a typed value")
  end
  local item, j = parseScalar(raw, s, #kind + 3, kind)
  if j <= #s then fail(raw, "a typed value") end
  return item
end

function values.string(raw)
  local v = values.typed(raw)
  if v.kind ~= "string" then fail(raw, "a string") end
  return v.value
end

-- The items of a 'steamVariantList:list: ...' value, the form contexts and many properties use.
function values.list(raw)
  local s = tostring(raw)
  if sub(s, 1, #LIST) ~= LIST then fail(raw, "a steamVariantList") end
  local items, j = parseItems(raw, s, #LIST + 1)
  if j <= #s then fail(raw, "a steamVariantList") end
  return items
end

return values
