-- 17-ask-and-report.lua took the answer typed into its box and made a flow titled with it, with it as a staff text,
-- commas and ampersands intact. args.answer is what the test typed.
local checks = require("checks")

return function(p, run, args)
  local said = 'wrote "' .. args.answer .. '" at the start of flow 3'
  p:check("said what it wrote", run.printed[1] == said, run.printed[1])
  local flows = #DoApp.DoApp().currentScore.flows
  p:check("a third flow", flows == 3, flows)
  p:check("titled with the answer", checks.flowTitles()[3] == args.answer, checks.flowTitles()[3])
  local texts = checks.joined(checks.texts(3))
  p:check("the answer as a text", texts == "0|" .. args.answer, texts)
  checks.musicUnchanged(p)
end
