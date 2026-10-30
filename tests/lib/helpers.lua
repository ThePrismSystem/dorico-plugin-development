-- Loads a helper block out of an example, so stock Lua can unit-test it. A block runs from "-- helper: <name>" to
-- "-- end helper: <name>" and defines one local of that name.
local helpers = {}

local root = (arg and arg[0] or ""):match("^(.*[/\\])tests[/\\]") or "./"

function helpers.text(path, name)
  local f = assert(io.open(root .. path, "rb"))
  local source = f:read("*a")
  f:close()
  local body = source:match("\n%-%- helper: " .. name .. "\r?\n(.-)\n%-%- end helper: " .. name)
  if not body then error("no helper " .. name .. " in " .. path, 2) end
  return body
end

-- The block's value. DoApp and DoCore are left out, so a helper that needs Dorico still loads and fails only when
-- it is called.
function helpers.load(path, name)
  local chunk = assert(load(helpers.text(path, name) .. "\nreturn " .. name, "=" .. path .. ":" .. name))
  return chunk()
end

return helpers
