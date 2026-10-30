-- Zip archives for tests: every entry stored uncompressed, with a real CRC, so scorereader.zip reads them.
local build = {}

local band, bxor, rshift = bit32.band, bit32.bxor, bit32.rshift

local function u16(n) return string.char(n % 256, math.floor(n / 256) % 256) end
local function u32(n) return u16(n % 65536) .. u16(math.floor(n / 65536)) end

local CRC = {}
for i = 0, 255 do
  local c = i
  for _ = 1, 8 do
    if c % 2 == 1 then c = bxor(rshift(c, 1), 0xEDB88320) else c = rshift(c, 1) end
  end
  CRC[i] = c
end

local function crc32(s)
  local c = 0xFFFFFFFF
  for i = 1, #s do c = bxor(rshift(c, 8), CRC[band(bxor(c, s:byte(i)), 0xFF)]) end
  return bxor(c, 0xFFFFFFFF)
end

-- entries: {{name, data}, ...} in archive order.
function build.archive(entries)
  local body, central = {}, {}
  local offset = 0
  for _, e in ipairs(entries) do
    local name, data = e[1], e[2]
    local sizes = u32(crc32(data)) .. u32(#data) .. u32(#data)
    local header = "PK\3\4" .. u16(20) .. u16(0) .. u16(0) .. u16(0) .. u16(0) .. sizes .. u16(#name) .. u16(0) .. name
    body[#body + 1] = header .. data
    central[#central + 1] = "PK\1\2" .. u16(20) .. u16(20) .. u16(0) .. u16(0) .. u16(0) .. u16(0) .. sizes
      .. u16(#name) .. u16(0) .. u16(0) .. u16(0) .. u16(0) .. u32(0) .. u32(offset) .. name
    offset = offset + #header + #data
  end
  local dir = table.concat(central)
  return table.concat(body) .. dir .. "PK\5\6" .. u16(0) .. u16(0) .. u16(#entries) .. u16(#entries) .. u32(#dir)
    .. u32(offset) .. u16(0)
end

return build
