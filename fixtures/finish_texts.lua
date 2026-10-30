-- Finishes the imported texts fixture on its scratch copy, as a user might: flips one text below the staff with
-- Edit.FlipItem, colours another by event id, and adds a staff text with createText and makes it a system text. It
-- then checks the fixture holds what texts.expected.json says, and that createText makes a text in the default
-- paragraph style, which the find and replace recipe relies on. fixtures/build_texts.py runs it.
local here = debug.getinfo(1, "S").source:match("^@(.*[/\\])")
local repo = here .. "../"
local mine = here .. "?.lua;" .. repo .. "spikes/lib/?.lua;" .. repo .. "lib/?.lua"
for name in pairs(package.loaded) do
  if name:match("^scorereader") or package.searchpath(name, mine) then package.loaded[name] = nil end
end
if not package.path:find(mine, 1, true) then package.path = mine .. ";" .. package.path end
local probe = require("probe")

probe.run("finish_texts", function(p)
  local json = require("json")
  local savedcopy = require("scorereader.dorico.savedcopy")
  local edit = require("scorereader.dorico.edit")
  local values = require("scorereader.values")
  local f = assert(io.open(here .. "texts.expected.json", "rb"))
  local expected = json.decode(f:read("*a"))
  f:close()
  local app = DoApp.DoApp()
  app:doCommand("NoteInput.Exit")
  app:doCommand("Window.SwitchMode?WindowMode=kWriteMode")
  local opts = { dir = probe.runDir }

  local function textAt(s, bar)
    for _, e in ipairs(s.flows[1].events) do
      if e.kind == "text" and values.toNumber(e.position) == 4 * (bar - 1) then return e end
    end
  end
  local s = savedcopy.read(app, opts)
  local below, coloured = textAt(s, expected.belowBar), textAt(s, expected.colouredBar)
  if not p:check("the texts to flip and colour came in", below ~= nil and coloured ~= nil) then return end
  app:doCommand("Edit.SelectNone")
  edit.select(app, below)
  app:doCommand("Edit.FlipItem")
  app:doCommand("Edit.SelectNone")
  edit.setProperty(app, coloured, "kEventColour", expected.colour)

  local flute = app.currentScore.flows[1].voiceStreams[1]
  local pos = 4 * (expected.systemText.bar - 1)
  local made = flute:createText(DoCore.RhythmicLength(pos), DoCore.RhythmicLength(0), expected.systemText.words)
  local mid = savedcopy.read(app, opts)
  local new = mid.events[made.id]
  p:check("createText makes a text in the default paragraph style",
    new and new.paragraphs[1].style == "paragraph.defaulttext", new and new.paragraphs[1].style)
  edit.select(app, new)
  app:doCommand("Edit.ChangeStaffTextToSystemText")
  app:doCommand("Edit.SelectNone")

  local after = savedcopy.read(app, opts)
  local score = require("scorereader.score")
  local got, want = {}, {}
  for _, e in ipairs(after.flows[1].events) do
    if e.kind == "text" then
      local owner = score.ownerOf(after, e)
      got[#got + 1] = string.format("%s|%g|%s|%s|%s", owner and owner.name or "-", values.toNumber(e.position) / 4 + 1,
        e.words, tostring(score.above(after, e, after.layouts[1].id)), tostring(e.system))
    end
  end
  for _, t in ipairs(expected.texts) do
    want[#want + 1] = string.format("%s|%g|%s|%s|%s", t.player, t.bar, t.words, tostring(t.above), tostring(t.system))
  end
  table.sort(got)
  table.sort(want)
  p:check("the texts", table.concat(got, " / ") == table.concat(want, " / "), table.concat(got, " / "))
  local lyrics, chords = 0, {}
  for _, e in ipairs(after.flows[1].events) do
    if e.kind == "lyric" then lyrics = lyrics + 1 end
    if e.kind == "chordSymbol" then chords[#chords + 1] = tostring(e.name) end
  end
  p:check("the lyrics", lyrics == #expected.lyrics, lyrics)
  p:check("the chord symbols", table.concat(chords, " ") == "C Am G7", table.concat(chords, " "))
end)
