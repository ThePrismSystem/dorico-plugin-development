-- The library's top-level modules run outside Dorico, so they never name its globals. Only lib/scorereader/dorico/
-- may.
local here = debug.getinfo(1, "S").source:match("^@(.*[/\\])") or "./"
local dir = here .. "../lib/scorereader/"

local function modules()
  local cmd = package.config:sub(1, 1) == "\\" and ('dir /b "' .. dir:gsub("/", "\\") .. '*.lua" 2>nul')
    or ('ls "' .. dir .. '" 2>/dev/null')
  local p = io.popen(cmd)
  local out = {}
  for name in p:lines() do
    if name:match("%.lua$") then out[#out + 1] = name end
  end
  p:close()
  return out
end

return {
  no_module_names_dorico = function(t)
    local found = modules()
    t:ok(#found > 0, "modules in " .. dir)
    for _, name in ipairs(found) do
      local f = assert(io.open(dir .. name, "rb"))
      local code = f:read("*a"):gsub("%-%-[^\n]*", "")
      f:close()
      t:ok(not code:find("DoApp", 1, true) and not code:find("DoCore", 1, true), name .. " names DoApp or DoCore")
    end
  end,
}
