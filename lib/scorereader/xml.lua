-- score.xml, the other way a .dorico can hold its score (Steinberg's shipped examples use it). It is the same tree as
-- score.dtn: element names are node names, an element's text is its value, and array="true" marks a list. This reads
-- only that much XML and refuses anything else, so a change in what Dorico writes shows up as an error.
local xml = {}

local find, sub, char, floor = string.find, string.sub, string.char, math.floor

local function fail(reason)
  error("xml: " .. reason, 0)
end

local function utf8(code)
  if code < 0x80 then return char(code) end
  if code < 0x800 then return char(0xC0 + floor(code / 64), 0x80 + code % 64) end
  if code < 0x10000 then
    return char(0xE0 + floor(code / 4096), 0x80 + floor(code / 64) % 64, 0x80 + code % 64)
  end
  return char(0xF0 + floor(code / 262144), 0x80 + floor(code / 4096) % 64, 0x80 + floor(code / 64) % 64,
    0x80 + code % 64)
end

local NAMED = { quot = '"', amp = "&", lt = "<", gt = ">", apos = "'" }

local function unescape(text)
  if not find(text, "&", 1, true) then return text end
  return (text:gsub("&([^&;]*)(;?)", function(body, semicolon)
    if semicolon == "" then fail("an & that starts no reference: &" .. body) end
    if NAMED[body] then return NAMED[body] end
    local code = body:match("^#%d+$") and tonumber(body:sub(2), 10) or body:match("^#x%x+$") and tonumber(body:sub(3), 16)
    if not code then fail("unknown reference &" .. body .. ";") end
    return utf8(code)
  end))
end

function xml.decode(text)
  local names, values, nameIndex, valueIndex = {}, { "" }, {}, { [""] = 0 }
  local nameOf, valueOf, kidsOf, arrayOf = {}, {}, {}, {}
  local count, stack, pending, rootClosed = 0, {}, {}, false

  local function intern(list, map, s)
    local i = map[s]
    if not i then
      list[#list + 1] = s
      i = #list - 1
      map[s] = i
    end
    return i
  end

  local function open(name, attrs)
    if rootClosed or (#stack == 0 and count > 0) then fail("a second root element <" .. name .. ">") end
    local id = count
    count = count + 1
    nameOf[id], valueOf[id] = intern(names, nameIndex, name), 0
    local rest = attrs:gsub('([%w_:]+)%s*=%s*"([^"]*)"', function(attr, v)
      if attr ~= "array" or v ~= "true" then fail("unknown attribute " .. attr .. '="' .. v .. '" on <' .. name .. ">") end
      arrayOf[id] = true
      return ""
    end)
    if rest:find("%S") then fail("attributes the reader can't read on <" .. name .. ">:" .. attrs) end
    local parent = stack[#stack]
    if parent then
      local kids = kidsOf[parent]
      if not kids then
        kids = {}
        kidsOf[parent] = kids
      end
      kids[#kids + 1] = id
    end
    return id
  end

  -- An element's text becomes its value when it holds no elements; beside elements, only whitespace may appear.
  -- pending[depth] is the open element's text so far, or false once it has a child.
  local function mixed(id)
    fail("text beside elements in <" .. names[nameOf[id] + 1] .. ">")
  end

  local pos, size = 1, #text
  while pos <= size do
    local lt = find(text, "<", pos, true)
    local between = sub(text, pos, (lt or size + 1) - 1)
    local depth = #stack
    if depth == 0 then
      if between:find("%S") then fail("text outside the root element") end
    elseif pending[depth] == false then
      if between:find("%S") then mixed(stack[depth]) end
    else
      pending[depth] = pending[depth] .. between
    end
    if not lt then break end
    local gt = find(text, ">", lt, true)
    if not gt then fail("a tag with no end") end
    local tag = sub(text, lt + 1, gt - 1)
    local first = sub(tag, 1, 1)
    if first == "?" then
      pos = gt + 1
    elseif sub(tag, 1, 3) == "!--" then
      local e = find(text, "-->", lt + 4, true)
      if not e then fail("a comment with no end") end
      pos = e + 3
    elseif first == "/" then
      local name = tag:match("^/([%w_:%.%-]+)%s*$")
      local id = stack[#stack]
      if not name or not id or names[nameOf[id] + 1] ~= name then
        fail("</" .. tostring(name) .. "> doesn't close " .. (id and "<" .. names[nameOf[id] + 1] .. ">" or "anything"))
      end
      local text = pending[#stack]
      -- An empty list written across lines holds its indentation, which isn't a value: score.dtn gives it none.
      if text and arrayOf[id] and not text:find("%S") then text = "" end
      if text then valueOf[id] = intern(values, valueIndex, unescape(text)) end
      pending[#stack] = nil
      stack[#stack] = nil
      if #stack == 0 then rootClosed = true end
      pos = gt + 1
    else
      local selfClosing = sub(tag, -1) == "/"
      local name, attrs = tag:match("^([%w_:%.%-]+)(.-)/?$")
      if not name then fail("a tag that isn't an element: <" .. tag .. ">") end
      local depth = #stack
      if depth > 0 and pending[depth] then
        if pending[depth]:find("%S") then mixed(stack[depth]) end
        pending[depth] = false
      end
      local id = open(name, attrs)
      if selfClosing then
        if #stack == 0 then rootClosed = true end
      else
        stack[#stack + 1] = id
        pending[#stack] = ""
      end
      pos = gt + 1
    end
  end
  if #stack > 0 then fail("<" .. names[nameOf[stack[#stack]] + 1] .. "> is never closed") end
  if count == 0 then fail("no root element") end
  return { encoding = "xml", names = names, values = values, count = count, nameOf = nameOf, valueOf = valueOf,
    kidsOf = kidsOf, arrayOf = arrayOf, nameIndex = nameIndex }
end

return xml
