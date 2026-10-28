-- 05-names-from-the-text-export.lua read the sample's title, path, flow titles and instrument names out of the text
-- export, names with a comma and an ampersand included, and took its markers and its CSV away again.
local checks = require("checks")

-- The sample's MusicXML part names. The export names instruments without the "(B{@flat@})" Dorico adds to the
-- trumpet player's name.
local INSTRUMENTS = { "Flute", "Trumpet Zoë", "Violin, solo & tutti", "Piano" }

return function(p, run)
  local want = checks.expected()
  p:check("the project's title", checks.printed(run, "project: Sample"))
  local path
  for _, line in ipairs(run.printed) do path = path or line:match("^path: (.*)$") end
  p:check("the copy's path", path and path:match("/dorico%-examples%-run/scratch%.dorico$"), path)
  for n, flow in ipairs(want.flows) do
    p:check("flow " .. n .. "'s title", checks.printed(run, "flow " .. n .. ": " .. flow.title))
  end
  for n, name in ipairs(INSTRUMENTS) do
    p:check("instrument " .. n, checks.printed(run, "instrument " .. n .. ": " .. name))
  end

  local left = 0
  for _, flow in ipairs(DoApp.DoApp().currentScore.flows) do
    for _, stream in ipairs(flow.voiceStreams) do
      if stream:dump():find("names-from-the-text-export", 1, true) then left = left + 1 end
    end
  end
  p:check("no marker is left", left == 0, left)
  local dir = os.getenv("TEMP") or os.getenv("TMPDIR")
  local csv = io.open(dir .. "/names-from-the-text-export.csv", "rb")
  if csv then csv:close() end
  p:check("no CSV is left", csv == nil)
end
