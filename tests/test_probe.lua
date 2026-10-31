-- spikes/lib/probe.lua's scratch check, with Dorico stood in for: a script the runner sends to a scratch copy runs
-- only when the active project is that copy.
local probe = require("probe")
local json = require("json")

local TMP = (os.getenv("TEMP") or os.getenv("TMPDIR") or "/tmp"):gsub("\\", "/")

-- probe.run with these args, while the active project has this path and OpenScoreID. Returns the result and whether
-- the body ran.
local function runWith(args, path, id, opts)
  local argsFile = TMP .. "/probe-test-args.json"
  local f = assert(io.open(argsFile, "wb"))
  f:write(json.encode(args))
  f:close()
  local realDir, realPath, realApp = probe.runDir, probe.projectPath, DoApp
  probe.runDir = TMP .. "/probe-test-"
  probe.projectPath = function() return path end
  rawset(_G, "EXAMPLES_RUN", { args = argsFile })
  DoApp = { DoApp = function() return { currentScore = { openScoreID = id } } end }
  local ran = false
  local ok, result = pcall(probe.run, "test", function() ran = true end, opts)
  rawset(_G, "EXAMPLES_RUN", nil)
  DoApp = realApp
  probe.runDir, probe.projectPath = realDir, realPath
  os.remove(argsFile)
  os.remove(TMP .. "/probe-test-result.json")
  assert(ok, result)
  return result, ran
end

return {
  an_import_is_the_copy_only_with_the_id_the_runner_saw_open = function(t)
    -- an import has no path yet, like any project never saved, the user's own included
    t:eq(probe.isExpectedScratch({ path = "", openScoreID = 7 }, "", 7), true)
    t:eq(probe.isExpectedScratch({ path = "", openScoreID = 7 }, "", 8), false)
  end,

  an_import_without_an_id_is_never_the_copy = function(t)
    t:eq(probe.isExpectedScratch({ path = "" }, "", 7), false)
  end,

  a_saved_copy_is_found_by_its_path = function(t)
    t:eq(probe.isExpectedScratch({ path = "C:/T/scratch.dorico" }, "c:\\t\\scratch.dorico", 3), true)
    t:eq(probe.isExpectedScratch({ path = "C:/T/scratch.dorico" }, "C:/Music/mine.dorico", 3), false)
  end,

  a_saved_copy_given_an_id_needs_that_id_too = function(t)
    t:eq(probe.isExpectedScratch({ path = "C:/T/scratch.dorico", openScoreID = 7 }, "C:/T/scratch.dorico", 7), true)
    t:eq(probe.isExpectedScratch({ path = "C:/T/scratch.dorico", openScoreID = 7 }, "C:/T/scratch.dorico", 8), false)
  end,

  another_project_never_saved_is_refused = function(t)
    local result, ran = runWith({ runId = "r", expectScratch = { path = "", openScoreID = 7 } }, "", 8)
    t:eq(ran, false, "the body ran")
    t:eq(result.ok, false)
    t:eq(result.facts.scratchVerified, false)
    t:ok(tostring(result.error):find("refusing to run", 1, true), result.error)
  end,

  the_copy_runs_and_reports_its_id = function(t)
    local result, ran = runWith({ runId = "r", expectScratch = { path = "", openScoreID = 7 } }, "", 7)
    t:eq(ran, true)
    t:eq(result.ok, true, result.error)
    t:eq(result.facts.scratchVerified, true)
    t:eq(result.facts.scratchScoreID, 7)
  end,

  a_scratch_only_script_refuses_without_a_copy_named = function(t)
    -- run from Script > Run Script, or with run_lua.py --on-active, a case would change the user's own project
    local result, ran = runWith({ runId = "r" }, "C:/Music/mine.dorico", 3, { scratchOnly = true })
    t:eq(ran, false, "the body ran")
    t:eq(result.ok, false)
    t:eq(result.facts.scratchVerified, false)
    t:ok(tostring(result.error):find("refusing to run", 1, true), result.error)
  end,

  a_script_not_marked_scratch_only_runs_on_the_active_project = function(t)
    local _, ran = runWith({ runId = "r" }, "C:/Music/mine.dorico", 3)
    t:eq(ran, true)
  end,
}
