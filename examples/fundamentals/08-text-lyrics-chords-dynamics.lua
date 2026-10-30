-- Read texts, lyrics, chord symbols and dynamics from a saved copy, none of which Lua can read for itself.
-- What it does: prints one line per item, with tabs between the columns:
--   text: flow, player, position, above or below in the full score (or by the text's own placement when there is
--     no full score), staff or system, paragraph style, words (and "formatted" when a fragment has a style of its
--     own)
--   lyric: flow, player, position, line, syllable (begin, middle, end or single), text, "melisma" or "-"
--   chord: flow, position, root, name (or "-"), quality, interval
--   dynamic: flow, player, position, name, kind (immediate, gradual, force or combined)
--   total: how many texts, lyrics, chords and dynamics it printed
-- Changes: nothing (read-only).
-- Undo: nothing to undo.
-- Builds on: 04-read-the-saved-copy.lua. Open Script > Show Script Console to read what it prints.
--
-- Each item is an event in s.flows[i].events, with a kind and the fields the reader gives that kind (types/
-- scorereader.lua lists them). score.ownerOf(s, e) is the player whose stream holds it; chord symbols are in the
-- flow's timebase stream, so they have no player. A dynamic event can hold several dynamics, each with its own
-- position: a hairpin is one, and "fp" is a combined one. The reader names a chord only when it is a plain major,
-- minor or dominant seventh; any other keeps its root, quality and interval. Tempos, rehearsal marks, playing
-- techniques, clefs, and key and time signatures are events too (docs/file-format.md).

-- helper: guard
-- The app and the open project, or the app and nil when no project is open. The read of app.currentScore goes
-- through pcall in case it raises an error then instead of giving nil, which no run here has checked. Such an error
-- is printed with the advice, in case it means something else.
local function guard()
  local app = DoApp.DoApp()
  local ok, score = pcall(function() return app.currentScore end)
  if ok and score then return app, score end
  local advice = "Open a project first, then run this script again."
  print(ok and advice or advice .. " Reading the open project gave an error: " .. tostring(score))
  return app, nil
end
-- end helper: guard

-- helper: readCopy
-- Reads a saved copy of the open project with the reader library, or prints why it couldn't and gives nil. The
-- library is lib/ two folders up in this repository, or a lib folder beside the script once both are copied into
-- Script Plug-ins. Dorico keeps one Lua state, so the library's modules from an earlier run are cleared, and its
-- folders are moved to the front of the module path, where no other copy of the library can come before them. The
-- library loads outside the pcall, so a missing or broken library isn't reported as a project it couldn't read.
local function readCopy(app)
  local here = debug.getinfo(1, "S").source:match("^@(.*[/\\])") or ""
  local paths = here .. "../../lib/?.lua;" .. here .. "lib/?.lua;"
  for name in pairs(package.loaded) do
    if name:match("^scorereader") then package.loaded[name] = nil end
  end
  local at = package.path:find(paths, 1, true)
  if at then package.path = package.path:sub(1, at - 1) .. package.path:sub(at + #paths) end
  package.path = paths .. package.path
  if package.searchpath("scorereader.dorico.savedcopy", package.path) then
    local savedcopy = require("scorereader.dorico.savedcopy")
    local ok, s = pcall(savedcopy.read, app)
    if ok then return s end
    print("The reader couldn't read this project: " .. tostring(s))
  else
    print("Couldn't find the reader library: copy the lib folder beside this script, then run it again.")
  end
end
-- end helper: readCopy

local app, project = guard()
if not project then return end
local s = readCopy(app)
if not s then return end
local score = require("scorereader.score")
local values = require("scorereader.values")

local counts = { text = 0, lyric = 0, chord = 0, dynamic = 0 }
local function line(kind, ...)
  counts[kind] = counts[kind] + 1
  print(table.concat({ kind, ... }, "\t"))
end

-- Edit.FlipItem flips a text only in the layout on screen, so ask which side the full score shows.
local fullScore = score.fullScoreOf(s)

for n, flow in ipairs(s.flows) do
  for _, e in ipairs(flow.events) do
    local owner = score.ownerOf(s, e)
    local player = owner and owner.name or "-"
    local pos = values.positionText(e.position)
    if e.kind == "text" then
      local above = e.above
      if fullScore then above = score.above(s, e, fullScore.id) end
      local words = e.formatted and (e.words .. "\tformatted") or e.words
      line("text", n, player, pos, above and "above" or "below", e.system and "system" or "staff",
        e.paragraphs[1] and e.paragraphs[1].style or "-", words)
    elseif e.kind == "lyric" then
      line("lyric", n, player, pos, e.line, e.syllable, e.text, e.duration.num > 0 and "melisma" or "-")
    elseif e.kind == "chordSymbol" then
      line("chord", n, pos, e.root, e.name or "-", e.quality or e.rawQuality, e.interval or e.rawInterval)
    elseif e.kind == "dynamic" then
      for _, d in ipairs(e.dynamics) do
        line("dynamic", n, player, values.positionText(d.position), d.name, d.kind)
      end
    end
  end
end
print(table.concat({ "total", counts.text, counts.lyric, counts.chord, counts.dynamic }, "\t"))
