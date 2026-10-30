-- Finishes the imported reading fixture on its scratch copy: sets the note properties reading.expected.json lists
-- under "props", each by the route it names, and adds a second flow with four flute notes, since MusicXML holds one
-- flow. A "part" property is left to fixtures/build_reading.py, which needs the part on screen; this script reports
-- that note's ids. fixtures/build_reading.py runs it.
local here = debug.getinfo(1, "S").source:match("^@(.*[/\\])")
local mine = here .. "?.lua;" .. here .. "../spikes/lib/?.lua;" .. here .. "../lib/?.lua"
for name in pairs(package.loaded) do
  if package.searchpath(name, mine) then package.loaded[name] = nil end
end
if not package.path:find(mine, 1, true) then package.path = mine .. ";" .. package.path end
local probe = require("probe")

local function fraction(s)
  local a, b = s:match("^(%-?%d+)/(%d+)$")
  if a then return tonumber(a) / tonumber(b) end
  return tonumber(s)
end

probe.run("finish_reading", function(p)
  local dump = require("scorereader.dorico.dump")
  local edit = require("scorereader.dorico.edit")
  local commands = require("scorereader.dorico.commands")
  local json = require("json")
  local f = assert(io.open(here .. "reading.expected.json", "rb"))
  local expected = json.decode(f:read("*a"))
  f:close()
  local app = DoApp.DoApp()
  local score = app.currentScore
  local flow = score.flows[1]
  local names = {}
  for i, player in ipairs(expected.flows[1].players) do names[player.name] = i end
  app:doCommand("NoteInput.Exit")
  app:doCommand("Window.SwitchMode?WindowMode=kWriteMode")

  -- The note a property names: its stream, event id and block id, found through the player's place in the score.
  local function find(prop)
    local index = names[prop.player] or names[prop.player:match("^(%S+)")]
    local player = index and score.players[index]
    if not player then return nil, "no player " .. prop.player end
    local want = player.instruments[1].id
    for i, s in ipairs(flow.voiceStreams) do
      if flow.instruments[i].id == want then
        local parsed = dump.parse(s:dump())
        for _, ev in ipairs(parsed.events) do
          if ev.kind == "note" and ev.spelling == prop.spelling and math.abs(ev.pos - fraction(prop.pos)) < 1e-9 then
            return { stream = s, id = ev.id, block = edit.blockIdOf(s, ev.id, parsed) }
          end
        end
      end
    end
    return nil, "no " .. prop.spelling .. " at " .. prop.pos .. " for " .. prop.player
  end

  local function select(note)
    edit.select(app, { flowId = flow.id, id = note.id, blockId = note.block })
  end

  local deferred = {}
  for _, prop in ipairs(expected.props) do
    local label = prop.player .. " " .. prop.spelling .. " " .. prop.property .. " (" .. prop.how .. ")"
    local note, why = find(prop)
    if p:check("found " .. label, note ~= nil, why) then
      if prop.how == "lua" then
        local ok, err = pcall(function()
          for _, e in ipairs(note.stream.events) do
            if e.id == note.id then
              return assert(e.propertyTable:set(prop.property, DoCore.Variant.createString(prop.value),
                DoCore.PropertyContext()))
            end
          end
          error("not in stream.events")
        end)
        p:check("set " .. label, ok, err)
      elseif prop.how == "command" then
        select(note)
        app:doCommand(commands.build("Edit.SetNoteheadSetOverride", { { "NoteheadSetEntityID", prop.value } }))
      elseif prop.how == "byId" then
        app:doCommand(commands.changeProperty(flow.id, note.id, note.block, prop.property, prop.value))
      elseif prop.how == "menu" then
        select(note)
        app:doCommand(prop.value == "kSquareBrackets" and "Edit.ShowAccidentalInBrackets"
          or "Edit.ShowAccidentalInParentheses")
      elseif prop.how == "part" then
        local owner = score.players[names[prop.player]].instruments[1].id
        local layoutId
        for _, l in ipairs(score.layouts) do
          if #l.players == 1 and l.players[1].instruments[1].id == owner then layoutId = l.id end
        end
        if p:check("a part for " .. prop.player, layoutId ~= nil) then
          deferred[#deferred + 1] = { flowId = flow.id, eventId = note.id, blockId = note.block, layoutId = layoutId,
            property = prop.property, value = prop.value }
        end
      end
    end
  end
  app:doCommand("Edit.SelectNone")
  p:fact("deferred", deferred)

  local before = {}
  for _, fl in ipairs(score.flows) do before[fl.id] = true end
  app:doCommand("Project.Flow.New")
  local second
  for _, fl in ipairs(app.currentScore.flows) do
    if not before[fl.id] then second = fl end
  end
  if not p:check("a second flow was added", second ~= nil) then return end
  app:doCommand(commands.build("Project.Flow.Rename", { { "FlowID", second.id }, { "Name", expected.flows[2].title } }))
  local fluteId = app.currentScore.players[1].instruments[1].id
  local flute
  for i, s in ipairs(second.voiceStreams) do
    if not flute and second.instruments[i].id == fluteId then flute = s end
  end
  if p:check("the second flow has a flute voice", flute ~= nil) then
    for _, n in ipairs(expected.flows[2].players[1].notes) do
      flute:createNote(DoCore.RhythmicLength(fraction(n.pos)), DoCore.RhythmicLength(1),
        DoCore.MIDIPitchWithSpelling.fromString(n.spelling))
    end
  end
  local players = {}
  for _, pl in ipairs(app.currentScore.players) do players[#players + 1] = tostring(pl) end
  p:fact("players", players)
  p:fact("layouts", (function()
    local out = {}
    for _, l in ipairs(app.currentScore.layouts) do out[#out + 1] = { id = l.id, name = tostring(l) } end
    return out
  end)())
end)
