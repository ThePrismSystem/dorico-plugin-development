-- Read key and time signatures from a saved copy, and work out the bar and beat of every note from them.
-- What it does: prints a "key" line per key signature (flow, position, sharps or flats as a count of fifths, mode),
-- a "time" line per time signature (flow, position, numerator/denominator), and a "note" line per note (flow,
-- player, bar, beat, spelling), with tabs between the columns.
-- Changes: nothing (read-only).
-- Undo: nothing to undo.
-- Builds on: 04-read-the-saved-copy.lua and 08-text-lyrics-chords-dynamics.lua. Open Script > Show Script Console to
-- read what it prints.
--
-- Lua can't read a time signature or a key signature, so before the reader a script had to find bars through the text
-- export. The saved copy has every bar division (a time signature, or a barline with no new one) in the flow's timebase
-- stream, and the bars helper counts bars from them. A division in any other stream is left out. Beats are quarter
-- notes from the start of the bar, counted from 1, except in a pickup, whose beats count back from its end: a one-beat
-- pickup in 4/4 is on beat 4. Bar numbers count every bar from 1, a pickup at the start of a flow being bar 0, and
-- don't follow a bar number change. Dorico stores a pickup as the length of the first bar after its time signature
-- (e.pickup).

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

local app, project = guard()
if not project then return end
local s = readCopy(app)
if not s then return end
local score = require("scorereader.score")
local values = require("scorereader.values")

local function line(...) print(table.concat({ ... }, "\t")) end

for n, flow in ipairs(s.flows) do
  local divisions, endPos = {}, 0
  for _, e in ipairs(flow.events) do
    local pos = values.toNumber(e.position)
    endPos = math.max(endPos, pos + values.toNumber(e.duration))
    if e.kind == "keySignature" then
      line("key", n, values.positionText(e.position), e.fifths or "-", e.mode)
    elseif e.kind == "timeSignature" and flow.streamById[e.streamId].type == "timebase" then
      divisions[#divisions + 1] = { pos = pos, numerator = e.numerator, denominator = e.denominator,
        pickup = e.pickup and values.toNumber(e.pickup) }
      if e.numerator then line("time", n, values.positionText(e.position), e.numerator .. "/" .. e.denominator) end
    end
  end
  table.sort(divisions, function(a, b) return a.pos < b.pos end)
  local starts = bars.starts(divisions, endPos)
  for _, player in ipairs(s.players) do
    for _, e in ipairs(score.eventsOf(s, flow, player)) do
      if e.kind == "note" or e.kind == "grace" then
        local bar, beat = bars.at(starts, values.toNumber(e.position))
        line("note", n, player.name, bar, beat, e.spelling)
      end
    end
  end
end
