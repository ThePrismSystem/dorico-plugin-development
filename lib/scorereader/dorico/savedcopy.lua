-- Reading the open project: app:save(score, path) writes a copy of its current state, unsaved edits included, without
-- touching the project's own file, its path or its unsaved mark, and without adding to the undo history. The copy is
-- read with scorereader.score and deleted.
local score = require("scorereader.score")

local savedcopy = {}

local function readFile(path)
  local f = io.open(path, "rb")
  if not f then return nil end
  local bytes = f:read("*a")
  f:close()
  return bytes
end

local ENOENT = 2

-- true when the file is gone, a missing file included; otherwise nil and why.
local function remove(path)
  local ok, why, code = os.remove(path)
  if ok or code == ENOENT then return true end
  return nil, why
end

local function defaultDir()
  return ((os.getenv("TEMP") or os.getenv("TMPDIR") or "/tmp"):gsub("\\", "/")) .. "/"
end

-- The current project as scorereader.score.read gives it. opts: dir (a folder ending in a slash, the temp folder by
-- default), log (a function taking a line, told about a copy that can't be deleted), remove (how to delete the copy,
-- os.remove by default). app:save takes its path in UTF-8 and io.open in the code page, so the folder's path should
-- be plain ASCII.
function savedcopy.read(app, opts)
  opts = opts or {}
  local path = (opts.dir or defaultDir()) .. "scorereader-copy.dorico"
  local del = opts.remove or remove
  local function cleanUp()
    local gone, why = del(path)
    if not gone and opts.log then opts.log("the saved copy " .. path .. " could not be deleted: " .. tostring(why)) end
  end
  del(path)
  if app:save(app.currentScore, path) ~= true then
    cleanUp()
    error("scorereader: Dorico could not save a copy of the project to read", 0)
  end
  local ok, result = pcall(function()
    local bytes = readFile(path) or error("scorereader: the saved copy " .. path .. " could not be read", 0)
    return score.read(bytes)
  end)
  cleanUp()
  if not ok then error(result, 0) end
  return result
end

return savedcopy
