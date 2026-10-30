-- Opening a .dorico: unzip it and decode its score, from score.dtn when it has one (what Dorico 6 saves) or
-- score.xml (what Steinberg's shipped examples hold).
local zip = require("scorereader.zip")
local dtn = require("scorereader.dtn")
local xml = require("scorereader.xml")

local project = {}

-- {tree, encoding ("dtn" or "xml"), entries (every name in the archive, in order)}.
function project.read(bytes)
  local entries = zip.names(bytes)
  local binary = zip.entry(bytes, "score.dtn")
  if binary then return { tree = dtn.decode(binary), encoding = "dtn", entries = entries } end
  local text = zip.entry(bytes, "score.xml")
  if text then return { tree = xml.decode(text), encoding = "xml", entries = entries } end
  error("scorereader: not a Dorico project (no score.dtn or score.xml)", 0)
end

-- path must be in the code page io.open takes, which on Windows isn't UTF-8.
function project.readFile(path)
  local f = io.open(path, "rb")
  if not f then error("scorereader: cannot read " .. path, 0) end
  local bytes = f:read("*a")
  f:close()
  return project.read(bytes)
end

return project
