-- The library's pure modules run outside Dorico, so they never name its globals. Only lib/scorereader/dorico/ may.
local here = debug.getinfo(1, "S").source:match("^@(.*[/\\])") or "./"
local DIRS = { here .. "../lib/scorereader/", here .. "../lib/scorereader/read/" }

local function modules(dir)
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
    for _, dir in ipairs(DIRS) do
      local found = modules(dir)
      t:ok(#found > 0, "modules in " .. dir)
      for _, name in ipairs(found) do
        local f = assert(io.open(dir .. name, "rb"))
        local code = f:read("*a"):gsub("%-%-[^\n]*", "")
        f:close()
        t:ok(not code:find("DoApp", 1, true) and not code:find("DoCore", 1, true), name .. " names DoApp or DoCore")
      end
    end
  end,
}
