-- The binary tree a saved project keeps its score in (score.dtn inside the .dorico zip). Steinberg doesn't document
-- it. The layout below comes from files saved by Dorico 6.0 to 6.2 (docs/file-format.md), so the decoder refuses
-- anything that doesn't fit it exactly.
--
--   u32 4, u32 1, u32 nameCount, nameCount NUL-terminated element names
--   u32 valueCount, valueCount NUL-terminated values (value 0 is "")
--   u32 nodeCount, then one record per node, node 0 the root: a tag byte, a name index and a value index, and when
--   the tag has its 2 bit set, a child count and that many child node ids. Numbers after the tag are LEB128 varints.
--   The tag's 1 bit marks a node whose children are a list (score.xml writes it as array="true").
local dtn = {}

local byte, find, sub = string.byte, string.find, string.sub

local function fail(reason)
  error("dtn: " .. reason, 0)
end

function dtn.decode(bytes)
  local size = #bytes

  local function u32(p)
    if p + 3 > size then fail("input ends early") end
    local a, b, c, d = byte(bytes, p, p + 3)
    return a + b * 256 + c * 65536 + d * 16777216
  end

  local function strings(p, n)
    local out = {}
    for i = 1, n do
      local e = find(bytes, "\0", p, true)
      if not e then fail("input ends early") end
      out[i] = sub(bytes, p, e - 1)
      p = e + 1
    end
    return out, p
  end

  local function varint(p)
    local v, scale = 0, 1
    while true do
      local b = byte(bytes, p)
      if not b then fail("input ends early") end
      p = p + 1
      if b < 128 then return v + b * scale, p end
      v = v + (b - 128) * scale
      scale = scale * 128
    end
  end

  if size < 12 or u32(1) ~= 4 or u32(5) ~= 1 then fail("not a saved score") end
  local names, p = strings(13, u32(9))
  local values
  values, p = strings(p + 4, u32(p))
  local count = u32(p)
  p = p + 4
  local nameCount, valueCount = #names, #values
  local nameOf, valueOf, kidsOf, arrayOf = {}, {}, {}, {}
  for id = 0, count - 1 do
    local tag = byte(bytes, p)
    if not tag then fail("input ends early") end
    local name, value
    name, p = varint(p + 1)
    value, p = varint(p)
    if name >= nameCount or value >= valueCount then fail("node " .. id .. " names an entry out of range") end
    nameOf[id], valueOf[id] = name, value
    if tag % 2 == 1 then arrayOf[id] = true end
    if tag % 4 >= 2 then
      local n
      n, p = varint(p)
      local kids = {}
      for k = 1, n do
        local kid
        kid, p = varint(p)
        if kid >= count then fail("node " .. id .. " has a child out of range") end
        kids[k] = kid
      end
      kidsOf[id] = kids
    end
  end
  if p ~= size + 1 then fail("records end at byte " .. (p - 1) .. " of " .. size) end
  local nameIndex = {}
  for i, n in ipairs(names) do nameIndex[n] = i - 1 end
  return { encoding = "dtn", names = names, values = values, count = count, nameOf = nameOf, valueOf = valueOf,
    kidsOf = kidsOf, arrayOf = arrayOf, nameIndex = nameIndex }
end

return dtn
