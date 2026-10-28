-- The run folder shared with tools/run_lua.py: <temp>/dorico-examples-run/, with forward slashes. The runner's launcher
-- names it (EXAMPLES_RUN.dir), so both sides agree whatever their environments say. Otherwise TEMP on Windows; macOS and
-- Linux have TMPDIR (or nothing), so fall back in that order.
return function()
  local run = rawget(_G, "EXAMPLES_RUN")
  if type(run) == "table" and run.dir then return run.dir end
  local temp = os.getenv("TEMP") or os.getenv("TMP") or os.getenv("TMPDIR") or "/tmp"
  return (temp:gsub("\\", "/"):gsub("/$", "")) .. "/dorico-examples-run/"
end
