-- The examples that read a saved copy, run in stock Lua on the fixtures, then checked by the check files the in-Dorico
-- suite uses. A stand-in app's save copies the fixture to the path the reader asks for, and its doCommand records each
-- command. 06 is left out: it reads Dorico's own dumps.
local ROOT = (arg and arg[0] or ""):match("^(.*[/\\])tests[/\\]") or "./"
local FIXTURES = ROOT .. "fixtures/6.2.30/"
local SAMPLE, READING = FIXTURES .. "sample.dorico", FIXTURES .. "reading.dorico"
local PICKUP = FIXTURES .. "pickup.dorico"
local CHECKS = ROOT .. "tests/dorico/lib/?.lua;"

local function copy(src, dst)
  local f = assert(io.open(src, "rb"))
  local bytes = f:read("*a")
  f:close()
  local g = assert(io.open(dst, "wb"))
  g:write(bytes)
  g:close()
  return true
end

-- Runs an example with DoApp standing in for Dorico, and puts back what it changed. What it printed, and the commands
-- it sent.
local function run(example, fixture)
  local printed, sent = {}, {}
  local app = { currentScore = { flows = {} }, save = function(_, _, path) return copy(fixture, path) end,
    doCommand = function(_, command) sent[#sent + 1] = command end }
  local path, realPrint = package.path, print
  DoApp = { DoApp = function() return app end }
  print = function(...) printed[#printed + 1] = table.concat({ ... }, "\t") end
  local ok, err = pcall(dofile, ROOT .. example)
  print, DoApp, package.path = realPrint, nil, path
  if not ok then error(err, 0) end
  return printed, sent
end

-- Runs a check file on what an example printed; how many checks it made, and the failures.
local function check(name, printed, args)
  local path = package.path
  package.path = CHECKS .. path
  local made, failed = 0, {}
  local p = { check = function(_, label, ok, detail)
    made = made + 1
    if not ok then failed[#failed + 1] = label .. ": " .. tostring(detail) end
    return ok
  end }
  local ok, err = pcall(function()
    assert(loadfile(ROOT .. "tests/dorico/checks/" .. name))()(p, { printed = printed, ok = true }, args)
  end)
  package.path = path
  if not ok then error(err, 0) end
  return made, failed
end

local function passes(t, example, fixture, checkName)
  local made, failed = check(checkName, (run("examples/fundamentals/" .. example, fixture)))
  t:ok(made > 0, checkName .. " made no checks")
  t:eq(#failed, 0, table.concat(failed, " / "))
end

return {
  read_the_saved_copy = function(t)
    passes(t, "04-read-the-saved-copy.lua", SAMPLE, "04-read-the-saved-copy.lua")
  end,

  names_and_titles = function(t)
    passes(t, "05-names-and-titles.lua", SAMPLE, "05-names-and-titles.lua")
  end,

  values_per_layout = function(t)
    passes(t, "07-values-per-layout.lua", READING, "07-values-per-layout.lua")
  end,

  text_lyrics_chords_dynamics = function(t)
    passes(t, "08-text-lyrics-chords-dynamics.lua", READING, "08-text-lyrics-chords-dynamics.lua")
  end,

  bars_keys_and_times = function(t)
    passes(t, "09-bars-keys-and-times.lua", READING, "09-bars-keys-and-times.lua")
  end,

  bars_after_a_pickup = function(t)
    passes(t, "09-bars-keys-and-times.lua", PICKUP, "09-bars-keys-and-times.pickup.lua")
  end,

  a_time_signature_outside_the_timebase_stream_makes_no_bar = function(t)
    local score = require("scorereader.score")
    local values = require("scorereader.values")
    local s = score.readFile(READING)
    local flow, stave, fake = s.flows[1], nil, nil
    for _, stream in ipairs(flow.streams) do
      if stream.type == "stave" then stave = stave or stream end
    end
    for _, e in ipairs(flow.events) do
      if e.kind == "timeSignature" then fake = fake or setmetatable({}, { __index = e }) end
    end
    fake.streamId, fake.position, fake.numerator, fake.denominator = stave.id, values.position("2"), 2, 4
    flow.events[#flow.events + 1] = fake
    -- readCopy clears the library's modules but not package.preload, so this stands in for the saved copy.
    package.preload["scorereader.dorico.savedcopy"] = function() return { read = function() return s end } end
    local ok, printed = pcall(run, "examples/fundamentals/09-bars-keys-and-times.lua", READING)
    package.preload["scorereader.dorico.savedcopy"] = nil
    t:ok(ok, tostring(printed))
    local made, failed = check("09-bars-keys-and-times.lua", printed)
    t:ok(made > 0, "no checks")
    t:eq(#failed, 0, table.concat(failed, " / "))
  end,

  set_a_property_by_id_sends_a_command_per_note = function(t)
    local printed, sent = run("examples/fundamentals/13-set-a-property-by-id.lua", SAMPLE)
    t:eq(#sent, 5)
    for _, command in ipairs(sent) do
      t:ok(command:match("^EventEdit%.ChangeProperty%?FlowID=%d+&EventID=%d+&EventBlockID=%d+&Type=kEventColour"
        .. "&Value=#ff1f78b4$"), command)
    end
    -- The stand-in's second copy is the fixture again, so no colour took.
    t:eq(printed[1], "1\tFlute\t4\tG5\tnot coloured")
    t:eq(#printed, 6)
    t:eq(printed[6], "total\t0\t5")
  end,

  chord_symbols_say_which_chords_dorico_didnt_put_in = function(t)
    local printed, sent = run("examples/recipes/chord-symbols.lua", SAMPLE)
    local definitions = {}
    for _, command in ipairs(sent) do
      definitions[#definitions + 1] = command:match("^NoteInput%.AcceptCurrentChordSymbolTextInput%?Definition=(%w+)")
    end
    t:eq(table.concat(definitions, " "), "C Am F G7")
    -- The stand-in's second copy is the fixture again, so none of them went in.
    t:eq(table.concat(printed, " / "), "flow 1, bar 1: C / flow 1, bar 2: Am / flow 1, bar 3: F / flow 1, bar 4: G7"
      .. " / flow 1, bar 1: Dorico put in no chord symbol for C / flow 1, bar 2: Dorico put in no chord symbol for Am"
      .. " / flow 1, bar 3: Dorico put in no chord symbol for F / flow 1, bar 4: Dorico put in no chord symbol for G7")
  end,
}
