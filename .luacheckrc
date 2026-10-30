-- Dorico runs Lua 5.2 with its compatibility functions turned on.
std = "lua52c"
-- Line length isn't checked, since rewrapping the long lines would only add churn.
max_line_length = false
-- A method keeps the colon call even when it doesn't need self.
self = false

-- Dorico's object model. lib/scorereader outside dorico/ gets none of it, which tests/test_scorereader_pure.lua also
-- checks.
local dorico = { "DoApp", "DoCore" }
files["lib/scorereader/dorico/**/*.lua"] = { read_globals = dorico }
files["spikes/**/*.lua"] = { read_globals = dorico }
files["tests/dorico/**/*.lua"] = { read_globals = dorico }
files["fixtures/**/*.lua"] = { read_globals = dorico }
-- The editor definitions declare the globals themselves.
files["types/**/*.lua"] = { globals = dorico }
-- A helper block takes the helpers it uses as arguments named after them, so it can be loaded and tested alone.
files["examples/**/*.lua"] = { read_globals = dorico, ignore = { "431" } }
-- These keep state in a global between runs, since Dorico keeps one Lua state for the session.
files["examples/fundamentals/19-key-command.lua"] = { read_globals = dorico, globals = { "DoricoExamplesKeyCommandRuns" } }
files["examples/recipes/hotkey-colour-cycle.lua"] = { read_globals = dorico, ignore = { "431" },
  globals = { "DoricoExamplesColourCycle" } }
files["tests/dorico/checks/19-key-command*.lua"] = { read_globals = { "DoApp", "DoCore", "DoricoExamplesKeyCommandRuns" },
  globals = { "DoricoExamplesTestKeyCommandCount" } }
files["tests/dorico/checks/hotkey-colour-cycle*.lua"] = { read_globals = { "DoApp", "DoCore", "DoricoExamplesColourCycle" } }
files["spikes/00_smoke.lua"] = { read_globals = dorico, globals = { "EXAMPLES_SMOKE_MARKER" } }
files["spikes/s2_counter.lua"] = { read_globals = dorico, globals = { "EXAMPLES_S2_COUNT" } }
-- The probe looks for globals the object model might have, and reports which exist.
files["spikes/class_info_probe.lua"] = { read_globals = { "DoApp", "DoCore", "DoScore", "class_info", "class_names" } }
-- The score functions all take the score first, whether or not they need it.
files["lib/scorereader/score.lua"] = { ignore = { "212/s" } }
-- The stock-Lua tests stand in for Dorico's globals, its print, and the os and io calls the examples make.
files["tests/*.lua"] = { globals = { "DoApp", "DoCore", "print", "os", "io", "package" } }
files["tests/dorico/case_example.lua"] = { read_globals = dorico, globals = { "print" } }
