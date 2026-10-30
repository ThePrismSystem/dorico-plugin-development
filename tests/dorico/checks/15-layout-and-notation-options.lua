-- 15-layout-and-notation-options.lua said which options it set, and the text export showed headings going. The
-- options' values are read back through the Remote API by the Python test, since Lua can't read them.
return function(p, run)
  p:check("the layout option", run.printed[1] == "full score (layout 0): flowHeadingBehaviour = kNoFlowHeadings",
    run.printed[1])
  p:check("the flow option", run.printed[2] == "flow 1 (id 0): barlineOptions.finalBarlineType = kDouble",
    run.printed[2])
  local gone = {}
  for i = 3, #run.printed do gone[run.printed[i]] = true end
  p:check("the first flow's heading left the export", gone["text frame gone: page 1: 1. Sample"])
  p:check("the second flow's heading left the export", gone["text frame gone: page 2: 2. Second movement"])
end
