-- Dorico runs Lua 5.2 with its compatibility functions turned on.
std = "lua52c"
-- Line length isn't checked, since rewrapping the long lines would only add churn.
max_line_length = false

-- Dorico's object model. lib/scorereader outside dorico/ gets none of it, which tests/test_scorereader_pure.lua also
-- checks.
local dorico = { "DoApp", "DoCore" }
files["lib/scorereader/dorico/**/*.lua"] = { read_globals = dorico }
files["examples/**/*.lua"] = { read_globals = dorico }
files["spikes/**/*.lua"] = { read_globals = dorico }
files["tests/dorico/**/*.lua"] = { read_globals = dorico }
files["fixtures/**/*.lua"] = { read_globals = dorico }
-- The editor definitions declare the globals themselves.
files["types/**/*.lua"] = { globals = dorico }
