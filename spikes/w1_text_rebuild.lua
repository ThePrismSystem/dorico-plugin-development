-- Spike W1: can a script change a text's words? TextEvent.text is read-only, so this deletes a text and creates it
-- again, then tries to restore its placement, system text and paragraph style, reading every result back from a
-- saved copy. Run on a scratch copy of the reading fixture:
--   python tools/run_lua.py spikes/w1_text_rebuild.lua --open fixtures/6.2.30/reading.dorico
local here = debug.getinfo(1, "S").source:match("^@(.*[/\\])")
local repo = here .. "../"
local mine = here .. "lib/?.lua;" .. repo .. "lib/?.lua"
for name in pairs(package.loaded) do
  if name:match("^scorereader") or package.searchpath(name, mine) then package.loaded[name] = nil end
end
if not package.path:find(mine, 1, true) then package.path = mine .. ";" .. package.path end
local probe = require("probe")

probe.run("w1_text_rebuild", function(p)
  local savedcopy = require("scorereader.dorico.savedcopy")
  local edit = require("scorereader.dorico.edit")
  local values = require("scorereader.values")
  local app = DoApp.DoApp()
  local opts = { dir = probe.runDir }
  app:doCommand("NoteInput.Exit")
  app:doCommand("Window.SwitchMode?WindowMode=kWriteMode")

  local function texts(s)
    local out = {}
    for _, e in ipairs(s.flows[1].events) do
      if e.kind == "text" then out[#out + 1] = e end
    end
    return out
  end
  local function streamOf(e)
    for _, flow in ipairs(app.currentScore.flows) do
      if flow.id == e.flowId then
        for _, st in ipairs(flow.allStreams) do
          if st.id == e.streamId then return st end
        end
      end
    end
  end

  local before = texts(savedcopy.read(app, opts))
  p:fact("before", (function()
    local out = {}
    for _, e in ipairs(before) do out[#out + 1] = { id = e.id, words = e.words, stream = e.streamId } end
    return out
  end)())

  -- Rebuild each: delete by id, create again in the same stream with new words
  local made = {}
  for i, e in ipairs(before) do
    local stream = streamOf(e)
    edit.select(app, e)
    app:doCommand("Edit.Delete")
    local ok, t = pcall(function()
      return stream:createText(DoCore.RhythmicLength(e.position.num, e.position.den), DoCore.RhythmicLength(0),
        "rebuilt " .. i)
    end)
    p:check("createText in stream " .. e.streamId, ok, ok and tostring(t) or tostring(t))
    if ok then made[i] = { id = t.id, flowId = e.flowId, streamId = e.streamId } end
  end

  -- Placement, system text and paragraph style, one each, through commands on the selected new text
  local mid = savedcopy.read(app, opts)
  local function find(s, id) return s.events[id] end
  local function selectNew(i)
    local e = find(mid, made[i].id)
    edit.select(app, e)
    return e
  end
  if made[1] then
    selectNew(1)
    app:doCommand("Edit.FlipItem")
  end
  if made[2] then
    selectNew(2)
    app:doCommand("Edit.ChangeStaffTextToSystemText")
  end
  if made[3] then
    local e = selectNew(3)
    for _, guess in ipairs({ "kTextParagraphStyle", "kParagraphStyle", "kTextParagraphStyleID" }) do
      app:doCommand("UI.InvokePropertyChangeValue?Type=" .. guess .. "&Value=paragraph.tempo")
    end
    app:doCommand("Edit.SelectNone")
    -- by id, the placement Edit.FlipItem stores, and paragraph style names in the same pattern
    edit.setProperty(app, e, "kTextEventAboveOrBelow", "kBelow")
    edit.setProperty(app, e, "kTextEventParagraphStyle", "paragraph.tempo")
    edit.setProperty(app, e, "kTextEventParagraphStyleID", "paragraph.tempo")
  end
  app:doCommand("Edit.SelectNone")

  local after = savedcopy.read(app, opts)
  local score = require("scorereader.score")
  local report = {}
  for _, e in ipairs(texts(after)) do
    local props = {}
    for _, x in ipairs(score.entries(after, e)) do
      props[#props + 1] = x.property .. "=" .. x.value .. "@" .. x.layout .. "/" .. x.instance
    end
    report[#report + 1] = { id = e.id, words = e.words, above = e.above, system = e.system, stream = e.streamId,
      style = e.paragraphs[1] and e.paragraphs[1].style, pos = values.positionText(e.position), props = props }
  end
  p:fact("after", report)
end)
