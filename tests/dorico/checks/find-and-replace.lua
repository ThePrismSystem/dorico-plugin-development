-- After find-and-replace.lua on the texts fixture, answered as a row of tests/dorico/test_examples.py: it printed the
-- lines and summary texts.expected.json lists for that row (args.row), and the texts, lyrics and chord symbols are
-- what the row says, with the rest as they were.
local checks = require("checks")

return function(p, run, args)
  local row = checks.json("texts.expected.json").rows[args.row]
  local got = {}
  for _, line in ipairs(run.printed) do
    if line:find("\tflow ", 1, true) then got[#got + 1] = line end
  end
  p:check("the lines", checks.joined(got) == checks.joined(row.lines),
    "got " .. table.concat(got, " / ") .. " | want " .. table.concat(row.lines, " / "))
  p:check("the summary", checks.printed(run, row.summary), row.summary)
  local now, want = checks.textsNow(row)
  p:check("the texts, lyrics and chord symbols", now == want, "got " .. now .. " | want " .. want)
end
