-- After find-and-replace.lua replaced "espress." with "espressivo" in flow 10 of the Somervell project: the plain text
-- at quarter 68 was rebuilt with the new words, and the one at quarter 30.5, which has formatting inside it and
-- another paragraph style, was listed and left as it was.
local checks = require("checks")

return function(p, run)
  local replaced, left = false, false
  for _, line in ipairs(run.printed) do
    if line:find("\tflow 10\t", 1, true) then
      replaced = replaced or line:find("espress. -> espressivo", 1, true) ~= nil
      left = left or line:find("espress.: left as it is, it has formatting inside it", 1, true) ~= nil
    end
  end
  p:check("listed the one replaced", replaced)
  p:check("listed the one left", left)
  p:check("the summary", checks.printed(run, "Replaced 1; left 1 as they were."))
  local s, _, values = checks.savedCopy()
  local texts = {}
  for _, e in ipairs(s.flows[10].events) do
    if e.kind == "text" and (e.words == "espress." or e.words == "espressivo") then
      texts[#texts + 1] = string.format("%g %s %s %s", values.toNumber(e.position), e.words, e.paragraphs[1].style,
        tostring(e.formatted))
    end
  end
  local got = checks.joined(texts)
  p:check("the texts", got == checks.joined({ "68 espressivo paragraph.defaulttext false",
    "30.5 espress. paragraph.user.default_text_2 true" }), got)
end
