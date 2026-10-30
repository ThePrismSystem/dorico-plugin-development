-- Reads each project named with the reader and says which it couldn't. tools/run_tests.py --inputs runs it on the
-- local copies of Steinberg's examples, which can't be committed:
--   lua52 tests/inputs.lua <project.dorico>...
local here = (arg and arg[0] or ""):match("^(.*[/\\])") or "./"
package.path = here .. "../lib/?.lua;" .. package.path
local score = require("scorereader.score")

local failed = 0
for i = 1, #arg do
  local ok, s = pcall(score.readFile, arg[i])
  local name = arg[i]:match("[^/\\]+$")
  if ok then
    local events = 0
    for _, flow in ipairs(s.flows) do events = events + #flow.events end
    print(string.format("ok    %s (%s, %d events)", name, s.format.fileVersion, events))
  else
    failed = failed + 1
    print(string.format("FAIL  %s: %s", name, tostring(s)))
  end
end
os.exit(failed == 0 and 0 or 1)
