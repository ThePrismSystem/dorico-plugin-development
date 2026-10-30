-- Recipe: a proofreading report of the notes outside their instrument's range, by bar and beat, without changing the
-- music.
-- What it does: reads a saved copy and prints one line per note outside its instrument's range, "<flow> bar <n> beat
-- <b>: <finding>", then how many it found.
-- Changes: nothing (read-only).
-- Undo: nothing to undo.
-- Builds on: 04-read-the-saved-copy.lua, 09-bars-keys-and-times.lua and 12-select-by-id.lua (the midi helper). Open
-- Script > Show Script Console to read what it prints.
--
-- The ranges are each instrument's own, from the saved copy: a standard range and a wider advanced one, both in
-- sounding pitch, as the reader gives them (instrument.range). A note past the advanced range is reported against
-- that one, and a note inside it but past the standard range against the standard one. Bars and beats come from the
-- bars helper, with beats counted in quarter notes from the start of the bar, so in 6/8 the second dotted-quarter
-- beat shows as beat 2.5. Parallel fifths and octaves have a recipe of their own, parallel-fifths.lua.
--
-- Nothing here looks for incomplete bars. A bar whose rests were removed looks the same to a script as a bar of
-- implicit rests (docs/spikes.md, S3).

-- helper: guard
-- The app and the open project, or the app and nil when no project is open. The read of app.currentScore goes
-- through pcall in case it raises an error then instead of giving nil, which no run here has checked.
local function guard()
  local app = DoApp.DoApp()
  local ok, score = pcall(function() return app.currentScore end)
  if ok and score then return app, score end
  print("Open a project first, then run this script again.")
  return app, nil
end
-- end helper: guard

-- helper: readCopy
-- Reads a saved copy of the open project with the reader library, or prints why it couldn't and gives nil. The
-- library is lib/ two folders up in this repository, or a lib folder beside the script once both are copied into
-- Script Plug-ins. Dorico keeps one Lua state, so the library's modules from an earlier run are cleared, and its
-- folders are moved to the front of the module path, where no other copy of the library can come before them.
local function readCopy(app)
  local here = debug.getinfo(1, "S").source:match("^@(.*[/\\])") or ""
  local paths = here .. "../../lib/?.lua;" .. here .. "lib/?.lua;"
  for name in pairs(package.loaded) do
    if name:match("^scorereader") then package.loaded[name] = nil end
  end
  local at = package.path:find(paths, 1, true)
  if at then package.path = package.path:sub(1, at - 1) .. package.path:sub(at + #paths) end
  package.path = paths .. package.path
  local ok, s = pcall(function() return require("scorereader.dorico.savedcopy").read(app) end)
  if ok then return s end
  print("The reader couldn't read this project: " .. tostring(s))
end
-- end helper: readCopy

-- helper: bars
-- Where bars start, from a flow's bar divisions, and the bar and beat of a position. Positions are quarter notes from
-- the start of the flow. A bar is numerator * 4 / denominator quarter notes long ("3+2" counts as 5). A time
-- signature partway through a bar starts a new bar there, and so does a barline-only division, keeping the time
-- signature. Where there is no length to go by (before the first time signature, or an open meter with no beats), a
-- bar runs to the next division. A flow with no time signature is one bar. A time signature's pickup makes its first
-- bar that long; that bar's beats count back from its end, so a one-beat pickup in 4/4 is on beat 4, and a pickup at
-- the start of the flow is bar 0.
--   bars.starts(divisions, endPos) -> {{bar, pos, length, offset}}; divisions: {{pos, numerator, denominator,
--     pickup}} in order, with no numerator for a barline-only division and pickup in quarter notes or nil
--   bars.at(starts, pos) -> bar, beat (from 1)
local bars = {}
do
  local function beats(numerator)
    local sum = 0
    for part in tostring(numerator):gmatch("%d+") do sum = sum + tonumber(part) end
    return sum
  end

  function bars.starts(divisions, endPos)
    local out, length = {}, nil
    local d1 = divisions[1]
    local base = (d1 and d1.pos == 0 and d1.numerator and d1.pickup and d1.pickup > 0) and -1 or 0
    local function add(pos, len, offset)
      out[#out + 1] = { bar = #out + 1 + base, pos = pos, length = len, offset = offset or 0 }
    end
    local first = d1 and d1.pos or endPos
    if first > 0 then add(0, first) end
    for i, d in ipairs(divisions) do
      if d.numerator then
        local n = beats(d.numerator) * 4 / d.denominator
        length = n > 0 and n or nil
      end
      local stop = divisions[i + 1] and divisions[i + 1].pos or endPos
      local pos = d.pos
      if length and d.numerator and d.pickup and d.pickup > 0 and pos < stop then
        add(pos, math.min(d.pickup, stop - pos), length - d.pickup)
        pos = pos + d.pickup
      end
      while pos < stop do
        local len = math.min(length or stop - pos, stop - pos)
        add(pos, len)
        pos = pos + len
      end
    end
    if #out == 0 then add(0, endPos) end
    return out
  end

  function bars.at(starts, pos)
    local found = starts[1]
    for _, b in ipairs(starts) do
      if b.pos <= pos then found = b else break end
    end
    return found.bar, pos - found.pos + 1 + found.offset
  end
end
-- end helper: bars

-- helper: midi
-- A spelling from the dump, such as "F#5", "Eb4" or "Bbb2", as a MIDI note number (middle C, "C4", is 60), or nil.
-- The octave goes with the letter, so "Cb4" is 59 and "B#3" is 60. "#" is a sharp, "x" a double sharp, "b" a flat.
local function midi(spelling)
  local letter, accidentals, octave = tostring(spelling):match("^([A-G])([#bx]*)(%-?%d+)$")
  if not letter then return nil end
  local n = ({ C = 0, D = 2, E = 4, F = 5, G = 7, A = 9, B = 11 })[letter] + (tonumber(octave) + 1) * 12
  for a in accidentals:gmatch(".") do
    n = n + ({ ["#"] = 1, x = 2, b = -1 })[a]
  end
  return n
end
-- end helper: midi

-- helper: outofrange
-- Whether a sounding MIDI pitch is outside an instrument's ranges as the reader gives them ({standard = "C4-A6",
-- advanced = "B3-D7"}, sounding): the advanced range is tried first, then the standard one. An instrument with no
-- range, such as unpitched percussion, has nothing out of range.
--   outofrange.check(pitch, range, midi) -> nil, or {side = "below" | "above", which = "advanced" | "standard", from,
--     to}; midi is the midi helper
local outofrange = {}
do
  function outofrange.check(pitch, range, midi)
    for _, which in ipairs({ "advanced", "standard" }) do
      local from, to = tostring((range or {})[which]):match("^([A-G][#bx]*%-?%d+)%-([A-G][#bx]*%-?%d+)$")
      if from and pitch < midi(from) then return { side = "below", which = which, from = from, to = to } end
      if from and pitch > midi(to) then return { side = "above", which = which, from = from, to = to } end
    end
  end
end
-- end helper: outofrange

local app, project = guard()
if not project then return end
local s = readCopy(app)
if not s then return end
local score = require("scorereader.score")
local values = require("scorereader.values")

-- helper: barsOf
-- Where a flow's bars start, through the bars helper, from the time signatures in its timebase stream. A time
-- signature in any other stream is left out.
local function barsOf(flow)
  local divisions, endPos = {}, 0
  for _, e in ipairs(flow.events) do
    local pos = values.toNumber(e.position)
    endPos = math.max(endPos, pos + values.toNumber(e.duration))
    if e.kind == "timeSignature" and flow.streamById[e.streamId].type == "timebase" then
      divisions[#divisions + 1] = { pos = pos, numerator = e.numerator, denominator = e.denominator,
        pickup = e.pickup and values.toNumber(e.pickup) }
    end
  end
  table.sort(divisions, function(a, b) return a.pos < b.pos end)
  return bars.starts(divisions, endPos)
end
-- end helper: barsOf

local total = 0
for n, flow in ipairs(s.flows) do
  local starts, findings = barsOf(flow), {}
  for _, player in ipairs(s.players) do
    for _, e in ipairs(score.eventsOf(s, flow, player)) do
      local instrument = e.kind == "note" and s.instruments[flow.streamById[e.streamId].instrumentId]
      local out = instrument and outofrange.check(e.pitch, instrument.range, midi)
      if out then
        findings[#findings + 1] = { pos = values.toNumber(e.position), text = string.format(
          "%s plays %s, %s its %s range (%s to %s)", player.name, e.spelling, out.side, out.which, out.from, out.to) }
      end
    end
  end
  table.sort(findings, function(x, y)
    if x.pos ~= y.pos then return x.pos < y.pos end
    return x.text < y.text
  end)
  for _, f in ipairs(findings) do
    local bar, beat = bars.at(starts, f.pos)
    print(string.format("%d bar %d beat %g: %s", n, bar, beat, f.text))
  end
  total = total + #findings
end
print(total .. (total == 1 and " finding" or " findings"))
