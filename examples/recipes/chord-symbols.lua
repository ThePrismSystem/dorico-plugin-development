-- Recipe: name the chords one player plays, bar by bar, and write them in as chord symbols.
-- What it does: reads a saved copy, finds the first player whose name starts with PLAYER and, for each bar, names the
-- chord its notes make (both hands of a piano, any voice). Where the chord changes from the bar before, it adds a
-- chord symbol at the first note that starts in the bar, through the chord symbol popover's own commands, and prints
-- "flow <n>, bar <b>: <chord>".
-- Changes: adds chord symbols where the flow has none, and changes the selection. A chord symbol already in place is
-- left as it is, since entering another there would replace it.
-- Undo: Edit > Undo takes the chord symbols back one at a time, three presses each: the chord symbol popover's
-- commands make undo steps of their own, unlike the rest of a run (the sample's four took eleven presses). To
-- remove them all at once, select the passage, filter the selection to chord symbols, and press Delete.
-- Builds on: 04-read-the-saved-copy.lua, 09-bars-keys-and-times.lua, 10-commands.lua and 12-select-by-id.lua. Open
-- Script > Show Script Console to read what it prints.
--
-- It names a chord where three or more pitch classes sound, from a short list of types (major, minor, diminished,
-- augmented, sus4, and the common sevenths). Inversions are named by their root. A bar's chord is the one all the
-- notes sounding in it make; when a passing note spoils that, the notes sounding on its first beat decide. A real
-- chord-finder would weigh beats and durations more than this does.
--
-- A chord symbol goes in as the popover would put it: select a note at the right place, then
--   NoteInput.StartChordSymbolInput
--   NoteInput.AcceptCurrentChordSymbolTextInput?Definition=<chord>&ChordSymbolEntryAdvanceType=kEndInput
-- The second command alone makes nothing.

local PLAYER = "Piano"

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

-- helper: chords
-- Names the chord a set of notes makes, as the chord symbol popover takes it ("C", "Am", "G7", "Bbmaj7"), or nil when
-- fewer than three pitch classes sound or no chord type fits them exactly. Notes are spellings from the dump. Their
-- octaves don't matter, except that the lowest note is tried as the root first, so an inversion is named by its root
-- and a chord that fits several roots (an augmented or diminished seventh chord) takes the bass note's.
--   chords.name(spellings) -> name or nil
local chords = {}
do
  local LETTERS = { C = 0, D = 2, E = 4, F = 5, G = 7, A = 9, B = 11 }
  local ACCIDENTALS = { ["#"] = 1, x = 2, b = -1 }
  -- Each chord type: the suffix the popover reads, and its pitch classes counted in semitones above the root.
  local TYPES = {
    { "", { 0, 4, 7 } }, { "m", { 0, 3, 7 } }, { "dim", { 0, 3, 6 } }, { "aug", { 0, 4, 8 } },
    { "sus4", { 0, 5, 7 } }, { "7", { 0, 4, 7, 10 } }, { "maj7", { 0, 4, 7, 11 } }, { "m7", { 0, 3, 7, 10 } },
    { "m7b5", { 0, 3, 6, 10 } }, { "dim7", { 0, 3, 6, 9 } },
  }

  local function parse(spelling)
    local letter, accidentals, octave = tostring(spelling):match("^([A-G])([#bx]*)(%-?%d+)$")
    if not letter then return nil end
    local n = LETTERS[letter]
    for a in accidentals:gmatch(".") do n = n + ACCIDENTALS[a] end
    return { class = n % 12, midi = n + (tonumber(octave) + 1) * 12, name = letter .. accidentals }
  end

  function chords.name(spellings)
    local notes, nameOf, count = {}, {}, 0
    for _, s in ipairs(spellings) do
      local n = parse(s)
      if n then
        notes[#notes + 1] = n
        if not nameOf[n.class] then
          nameOf[n.class] = n.name
          count = count + 1
        end
      end
    end
    if count < 3 then return nil end
    table.sort(notes, function(a, b) return a.midi < b.midi end)
    for _, root in ipairs(notes) do
      for _, kind in ipairs(TYPES) do
        local suffix, steps = kind[1], kind[2]
        if #steps == count then
          local fits = true
          for _, step in ipairs(steps) do
            if not nameOf[(root.class + step) % 12] then fits = false end
          end
          if fits then return nameOf[root.class] .. suffix end
        end
      end
    end
    return nil
  end
end
-- end helper: chords

-- helper: barchords
-- One chord a bar for a player's notes: the chord all the notes sounding in the bar make or, when they make none, the
-- chord of the notes sounding on its first beat. A chord is kept only where it changes from the bar before, and only
-- in a bar where a note starts, since a chord symbol goes in at a selected note.
--   barchords.of(notes, starts, name) -> {{bar, pos, name, note}}; notes: {{pos, duration, spelling}} in quarter
--     notes, starts as the bars helper gives them, name as chords.name; note is the first note to start in the bar
local barchords = {}
do
  function barchords.of(notes, starts, name)
    local out, last = {}, nil
    for _, b in ipairs(starts) do
      local from, to = b.pos, b.pos + b.length
      local all, first, starter = {}, {}, nil
      for _, n in ipairs(notes) do
        if n.pos < to and n.pos + n.duration > from then
          all[#all + 1] = n.spelling
          if n.pos <= from then first[#first + 1] = n.spelling end
        end
        if n.pos >= from and n.pos < to and (not starter or n.pos < starter.pos) then starter = n end
      end
      local chord = name(all) or name(first)
      if chord then
        if chord ~= last and starter then
          out[#out + 1] = { bar = b.bar, pos = starter.pos, name = chord, note = starter }
        end
        last = chord
      end
    end
    return out
  end
end
-- end helper: barchords

local app, project = guard()
if not project then return end
local s = readCopy(app)
if not s then return end
local commands = require("scorereader.dorico.commands")
local edit = require("scorereader.dorico.edit")
local score = require("scorereader.score")
local values = require("scorereader.values")

local player
for _, p in ipairs(s.players) do
  if not player and p.name:sub(1, #PLAYER) == PLAYER then player = p end
end
if not player then
  print(string.format("No player's name starts with %q. Change PLAYER at the top of the script.", PLAYER))
  return
end

-- Where each flow's bars start, from its time signatures, as 09 does.
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

-- Selecting only works outside note input, in Write mode.
app:doCommand("NoteInput.Exit")
app:doCommand(commands.build("Window.SwitchMode", { { "WindowMode", "kWriteMode" } }))

local count = 0
for n, flow in ipairs(s.flows) do
  local notes, existing = {}, {}
  for _, e in ipairs(score.eventsOf(s, flow, player)) do
    if e.kind == "note" then
      notes[#notes + 1] = { pos = values.toNumber(e.position), duration = values.toNumber(e.duration),
        spelling = e.spelling, event = e }
    end
  end
  -- Entering a chord symbol where one exists replaces it, so those places are left as they are.
  for _, e in ipairs(flow.events) do
    if e.kind == "chordSymbol" then existing[values.toNumber(e.position)] = true end
  end
  for _, c in ipairs(barchords.of(notes, barsOf(flow), chords.name)) do
    if existing[c.pos] then
      print(string.format("flow %d, bar %d: %s (a chord symbol is already there, left as it is)", n, c.bar, c.name))
    else
      edit.select(app, c.note.event)
      app:doCommand("NoteInput.StartChordSymbolInput")
      app:doCommand(commands.build("NoteInput.AcceptCurrentChordSymbolTextInput", { { "Definition", c.name },
        { "ChordSymbolEntryAdvanceType", "kEndInput" } }))
      print(string.format("flow %d, bar %d: %s", n, c.bar, c.name))
    end
    count = count + 1
  end
end
app:doCommand("Edit.SelectNone")
if count == 0 then print("No chords found.") end
