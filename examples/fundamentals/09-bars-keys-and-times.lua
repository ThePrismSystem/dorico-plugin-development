-- Read key and time signatures from a saved copy, and work out the bar and beat of every note from them.
-- What it does: prints a "key" line per key signature (flow, position, sharps or flats as a count of fifths, mode),
-- a "time" line per time signature (flow, position, numerator/denominator), and a "note" line per note (flow,
-- player, bar, beat, spelling), with tabs between the columns.
-- Changes: nothing (read-only).
-- Undo: nothing to undo.
-- Builds on: 04-read-the-saved-copy.lua and 08-text-lyrics-chords-dynamics.lua. Open Script > Show Script Console to
-- read what it prints.
--
-- Lua can't read a time signature or a key signature, so before the reader a script had to find bars through the
-- text export. The saved copy has every bar division (a time signature, or a barline with no new one) in the flow's
-- timebase stream, and the bars helper counts bars from them. Beats are quarter notes from the start of the bar,
-- counted from 1. Bar numbers here count every bar from 1; they don't follow a bar number change, and a pickup bar
-- counts as a whole bar, since none of the projects this was tried on had one to show how Dorico stores it.

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

-- helper: reader
-- Puts the reader library on the module path: lib/ two folders up in this repository, or a lib folder beside the
-- script once both are copied into Script Plug-ins. Dorico keeps one Lua state, so the library's modules from an
-- earlier run are cleared first.
local function reader()
  local here = debug.getinfo(1, "S").source:match("^@(.*[/\\])") or ""
  local paths = here .. "../../lib/?.lua;" .. here .. "lib/?.lua"
  for name in pairs(package.loaded) do
    if name:match("^scorereader") then package.loaded[name] = nil end
  end
  if not package.path:find(paths, 1, true) then package.path = paths .. ";" .. package.path end
end
-- end helper: reader

-- helper: bars
-- Where bars start, from a flow's bar divisions, and the bar and beat of a position. Positions are quarter notes from
-- the start of the flow. A bar is numerator * 4 / denominator quarter notes long ("3+2" counts as 5). A time
-- signature partway through a bar starts a new bar there, and so does a barline-only division, keeping the time
-- signature. Music before the first time signature is one bar, and so is a flow with none.
--   bars.starts(divisions, endPos) -> {{bar, pos, length}}; divisions: {{pos, numerator, denominator}} in order,
--     with no numerator for a barline-only division
--   bars.at(starts, pos) -> bar, beat (from 1)
local bars = {}
do
  local function beats(numerator)
    if type(numerator) == "number" then return numerator end
    local sum = 0
    for part in tostring(numerator):gmatch("%d+") do sum = sum + tonumber(part) end
    return sum
  end

  function bars.starts(divisions, endPos)
    local out, length = {}, nil
    local function add(pos, len) out[#out + 1] = { bar = #out + 1, pos = pos, length = len } end
    local first = divisions[1] and divisions[1].pos or endPos
    if first > 0 then add(0, first) end
    for i, d in ipairs(divisions) do
      if d.numerator then length = beats(d.numerator) * 4 / d.denominator end
      local stop = divisions[i + 1] and divisions[i + 1].pos or endPos
      local pos = d.pos
      while length and length > 0 and pos < stop do
        add(pos, math.min(length, stop - pos))
        pos = pos + length
      end
    end
    return out
  end

  function bars.at(starts, pos)
    local found = starts[1]
    for _, b in ipairs(starts) do
      if b.pos <= pos then found = b else break end
    end
    return found.bar, pos - found.pos + 1
  end
end
-- end helper: bars

local app, project = guard()
if not project then return end
reader()
local savedcopy = require("scorereader.dorico.savedcopy")
local score = require("scorereader.score")
local values = require("scorereader.values")

local ok, s = pcall(savedcopy.read, app)
if not ok then
  print("The reader couldn't read this project: " .. tostring(s))
  return
end

local function line(...) print(table.concat({ ... }, "\t")) end

for n, flow in ipairs(s.flows) do
  local divisions, endPos = {}, 0
  for _, e in ipairs(flow.events) do
    local pos = values.toNumber(e.position)
    endPos = math.max(endPos, pos + values.toNumber(e.duration))
    if e.kind == "keySignature" then
      line("key", n, values.positionText(e.position), e.fifths or "-", e.mode)
    elseif e.kind == "timeSignature" then
      divisions[#divisions + 1] = { pos = pos, numerator = e.numerator, denominator = e.denominator }
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
