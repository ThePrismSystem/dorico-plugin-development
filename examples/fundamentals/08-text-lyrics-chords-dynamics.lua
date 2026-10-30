-- Read texts, lyrics, chord symbols and dynamics from a saved copy, none of which Lua can read for itself.
-- What it does: prints one line per item, with tabs between the columns:
--   text: flow, player, position, above or below, staff or system, paragraph style, words (and "formatted" when a
--     fragment has a style of its own)
--   lyric: flow, player, position, line, syllable (begin, middle, end or single), text, "melisma" or "-"
--   chord: flow, position, root, name (or "-"), quality, interval
--   dynamic: flow, player, position, name, kind (immediate, gradual, force or combined)
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
  for _, e in ipairs(flow.events) do
    local owner = score.ownerOf(s, e)
    local player = owner and owner.name or "-"
    local pos = values.positionText(e.position)
    if e.kind == "text" then
      local words = e.formatted and (e.words .. "\tformatted") or e.words
      line("text", n, player, pos, e.above and "above" or "below", e.system and "system" or "staff",
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
