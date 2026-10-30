-- The examples that read a saved copy, run in stock Lua on the fixtures, then checked by the check files the in-Dorico
-- suite uses. A stand-in app's save copies the fixture to the path the reader asks for, and its doCommand records each
-- command. 06 is left out: it reads Dorico's own dumps.
local ROOT = (arg and arg[0] or ""):match("^(.*[/\\])tests[/\\]") or "./"
local FIXTURES = ROOT .. "fixtures/6.2.30/"
local SAMPLE, READING = FIXTURES .. "sample.dorico", FIXTURES .. "reading.dorico"
local PICKUP = FIXTURES .. "pickup.dorico"
local PARALLELS = FIXTURES .. "parallels.dorico"
local TMP = (os.getenv("TEMP") or os.getenv("TMPDIR") or "/tmp"):gsub("\\", "/")
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

-- Runs a script that asks through the form helper, with text standing in for what the box writes: a "key=value" line
-- per field. The helper takes its Windows route on any system, with TEMP pointing at a temporary folder. Lua 5.2's
-- require doesn't read package.config, so changing it changes only the route.
local function runAnswering(example, fixture, text)
  local realConfig, realGetenv, realExecute = package.config, os.getenv, os.execute
  package.config = "\\" .. realConfig:sub(2)
  os.getenv = function(name)
    if name == "TEMP" then return TMP end
    return realGetenv(name)
  end
  os.execute = function(command)
    local f = assert(io.open(command:match('%-Out "([^"]+)"'), "wb"))
    f:write(text)
    f:close()
    return true, "exit", 0
  end
  local ok, printed, sent = pcall(run, example, fixture)
  package.config, os.getenv, os.execute = realConfig, realGetenv, realExecute
  if not ok then error(printed, 0) end
  return printed, sent
end

local PARALLELS_ANSWER = "hidden=False\ncontrary=False\ndoublings=False\nouterOnly=False\nrestBreaks=True\n"
  .. "unisons=True\nclear=False\n"

-- Stands in for the score module, with this script's mark added to each note that has a colour stored for a layout,
-- as a colour set from the Properties panel is.
local function markedWithTheirOwn()
  return function(name)
    local real = assert(loadfile(ROOT .. "lib/scorereader/score.lua"))(name)
    local fake = setmetatable({}, { __index = real })
    function fake.entries(s, e)
      local list = real.entries(s, e)
      for _, x in ipairs(list) do
        if x.property == "kEventColour" and x.layout ~= -1 then
          local out = { { property = "kEventColour", value = 'string: "#ffd81b60"', layout = -1, instance = -1 } }
          for i, y in ipairs(list) do out[i + 1] = y end
          return out
        end
      end
      return list
    end
    return fake
  end
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

  parallel_fifths_finds_and_counts_on_the_fixture = function(t)
    local printed, sent = runAnswering("examples/recipes/parallel-fifths.lua", PARALLELS, PARALLELS_ANSWER)
    t:eq(#printed, 6, table.concat(printed, " / "))
    t:eq(printed[6], "5 found; 19 notes coloured, 1 kept their own colour; 0 old marks taken off.")
    t:eq(#sent, 19, "a command per note coloured")
  end,

  parallel_fifths_leaves_its_mark_on_a_note_with_a_colour_of_its_own = function(t)
    package.preload["scorereader.score"] = markedWithTheirOwn()
    local ok, printed, sent = pcall(runAnswering, "examples/recipes/parallel-fifths.lua", PARALLELS,
      (PARALLELS_ANSWER:gsub("clear=False", "clear=True")))
    package.preload["scorereader.score"] = nil
    t:ok(ok, tostring(printed))
    t:eq(table.concat(printed, " / "), "Took this script's colour off 0 notes. / Left it on 1 note that also has a "
      .. "colour of its own, since taking it off could take that colour too.")
    t:eq(#sent, 0, "nothing taken off")
  end,
}
