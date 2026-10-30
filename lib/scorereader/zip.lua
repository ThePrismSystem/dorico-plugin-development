-- The entries of a zip archive, which is what a .dorico project is. score.dtn (or score.xml) holds the music.
local inflate = require("scorereader.inflate")

local zip = {}

local byte = string.byte
local bxor, rshift = bit32.bxor, bit32.rshift

local function fail(reason)
  error("zip: " .. reason, 0)
end

local function u16(s, at)
  local a, b = byte(s, at, at + 1)
  return a + b * 256
end

local function u32(s, at)
  local a, b, c, d = byte(s, at, at + 3)
  return a + b * 256 + c * 65536 + d * 16777216
end

local CRC_TABLE = {}
for i = 0, 255 do
  local c = i
  for _ = 1, 8 do
    if c % 2 == 1 then c = bxor(rshift(c, 1), 0xEDB88320) else c = rshift(c, 1) end
  end
  CRC_TABLE[i] = c
end

-- Reading eight bytes per string.byte call and taking the low byte with % 256 makes the check about a third faster.
-- On a 2.6 MB score.dtn, checking a byte at a time took half of zip.entry's time.
local function crc32(s)
  local crc, T = 0xFFFFFFFF, CRC_TABLE
  local n = #s
  local whole = n - n % 8
  for i = 1, whole, 8 do
    local a, b, c, d, e, f, g, h = byte(s, i, i + 7)
    crc = bxor(rshift(crc, 8), T[bxor(crc % 256, a)])
    crc = bxor(rshift(crc, 8), T[bxor(crc % 256, b)])
    crc = bxor(rshift(crc, 8), T[bxor(crc % 256, c)])
    crc = bxor(rshift(crc, 8), T[bxor(crc % 256, d)])
    crc = bxor(rshift(crc, 8), T[bxor(crc % 256, e)])
    crc = bxor(rshift(crc, 8), T[bxor(crc % 256, f)])
    crc = bxor(rshift(crc, 8), T[bxor(crc % 256, g)])
    crc = bxor(rshift(crc, 8), T[bxor(crc % 256, h)])
  end
  for i = whole + 1, n do
    crc = bxor(rshift(crc, 8), T[bxor(crc % 256, byte(s, i))])
  end
  return bxor(crc, 0xFFFFFFFF)
end

-- The end of central directory record: the last "PK\5\6" in the final 64 KB, since a comment may follow it.
local function endRecord(bytes)
  local found, at = nil, math.max(1, #bytes - 65557)
  while true do
    local i = bytes:find("PK\5\6", at, true)
    if not i then break end
    found, at = i, i + 1
  end
  if not found or found + 21 > #bytes then fail("not a zip archive") end
  return found
end

-- Each central directory record in the order the archive lists them: the entry's name and the byte its record
-- starts at.
local function records(bytes)
  local e = endRecord(bytes)
  local count, offset = u16(bytes, e + 10), u32(bytes, e + 16)
  if count == 0xFFFF or offset == 0xFFFFFFFF then fail("ZIP64 archives are not supported") end
  local p, done = offset + 1, 0
  return function()
    if done == count then return nil end
    done = done + 1
    if bytes:sub(p, p + 3) ~= "PK\1\2" then fail("bad central directory") end
    local at, nameLength = p, u16(bytes, p + 28)
    p = p + 46 + nameLength + u16(bytes, p + 30) + u16(bytes, p + 32)
    return bytes:sub(at + 46, at + 45 + nameLength), at
  end
end

-- Every entry's name, in the order the archive lists them.
function zip.names(bytes)
  local names = {}
  for name in records(bytes) do names[#names + 1] = name end
  return names
end

-- The named entry's bytes, or nil when the archive has no such entry.
function zip.entry(bytes, name)
  for n, p in records(bytes) do
    if n == name then
      local method, crc, size = u16(bytes, p + 10), u32(bytes, p + 16), u32(bytes, p + 24)
      local l = u32(bytes, p + 42) + 1
      if bytes:sub(l, l + 3) ~= "PK\3\4" then fail("bad local header for " .. name) end
      local start = l + 30 + u16(bytes, l + 26) + u16(bytes, l + 28)
      local data
      if method == 0 then
        data = bytes:sub(start, start + size - 1)
      elseif method == 8 then
        data = inflate.raw(bytes, start)
      else
        fail("unsupported compression method " .. method .. " for " .. name)
      end
      if #data ~= size then fail("size mismatch for " .. name) end
      if crc32(data) ~= crc then fail("CRC mismatch for " .. name) end
      return data
    end
  end
  return nil
end

return zip
