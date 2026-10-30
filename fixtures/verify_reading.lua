-- Checks a scratch copy of fixtures/<version>/reading.dorico against fixtures/reading.expected.json: every player's
-- notes in every flow, by sounding spelling, position and duration, with players matched by their place in the
-- score. It reports the players' names as Dorico gives them. Read-only.
local here = debug.getinfo(1, "S").source:match("^@(.*[/\\])")
local mine = here .. "?.lua;" .. here .. "../spikes/lib/?.lua"
for name in pairs(package.loaded) do
  if package.searchpath(name, mine) then package.loaded[name] = nil end
end
if not package.path:find(mine, 1, true) then package.path = mine .. ";" .. package.path end
local probe = require("probe")

local function fraction(s)
  if type(s) ~= "string" then return s end
  local a, b = s:match("^(%-?%d+)/(%d+)$")
  if a then return tonumber(a) / tonumber(b) end
  return tonumber(s)
end

local function key(spelling, pos, duration, grace)
  return string.format("%s|%.6f|%s|%s", spelling, fraction(pos), grace and "" or string.format("%.6f",
    fraction(duration)), grace and "g" or "n")
end

probe.run("verify_reading", function(p)
  local dumpparse = require("dumpparse")
  local json = require("json")
  local f = assert(io.open(here .. "reading.expected.json", "rb"))
  local expected = json.decode(f:read("*a"))
  f:close()
  local app = DoApp.DoApp()
  local score = app.currentScore
  p:check("flows", #score.flows == #expected.flows, #score.flows)
  local names = {}
  for _, pl in ipairs(score.players) do names[#names + 1] = tostring(pl) end
  p:fact("players", names)

  for i, want in ipairs(expected.flows) do
    local flow = score.flows[i]
    if flow then
      for k, player in ipairs(want.players) do
        local owner = score.players[k] and score.players[k].instruments[1].id
        local got = {}
        for j, s in ipairs(flow.voiceStreams) do
          if flow.instruments[j].id == owner then
            for _, ev in ipairs(dumpparse.parse(s:dump()).events) do
              if ev.kind == "note" or ev.kind == "grace" then
                got[#got + 1] = key(ev.spelling, ev.pos, ev.duration, ev.kind == "grace")
              end
            end
          end
        end
        local wantKeys = {}
        for _, n in ipairs(player.notes) do wantKeys[#wantKeys + 1] = key(n.spelling, n.pos, n.duration, n.grace) end
        table.sort(wantKeys)
        table.sort(got)
        p:check("flow " .. i .. " " .. player.name, table.concat(wantKeys, " ") == table.concat(got, " "),
          "want " .. table.concat(wantKeys, " ") .. " | got " .. table.concat(got, " "))
      end
    end
  end
end)
