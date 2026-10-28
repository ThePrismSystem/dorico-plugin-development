-- Shared pieces for the check files in tests/dorico/checks/.
local checks = {}

local here = debug.getinfo(1, "S").source:match("^@(.*[/\\])")

-- fixtures/expected.json: what the sample holds.
function checks.expected()
  local json = require("json")
  local f = assert(io.open(here .. "../../../fixtures/expected.json", "rb"))
  local expected = json.decode(f:read("*a"))
  f:close()
  return expected
end

-- A printed line's tab-separated columns.
function checks.fields(line)
  local out = {}
  for field in (line .. "\t"):gmatch("([^\t]*)\t") do out[#out + 1] = field end
  return out
end

-- The sorted keys of a list, joined, so two sets can be compared as one string.
function checks.joined(keys)
  local copy = {}
  for i, k in ipairs(keys) do copy[i] = k end
  table.sort(copy)
  return table.concat(copy, " ")
end

-- True when the printed lines include this exact line.
function checks.printed(run, line)
  for _, l in ipairs(run.printed) do
    if l == line then return true end
  end
  return false
end

return checks
