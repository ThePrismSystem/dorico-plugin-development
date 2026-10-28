-- Checks a scratch copy of fixtures/sample.dorico against fixtures/expected.json: every player's notes in every
-- flow, by sounding spelling, position and duration. Read-only.
local here = debug.getinfo(1, "S").source:match("^@(.*[/\\])")
local mine = here .. "?.lua;" .. here .. "../spikes/lib/?.lua"
for name in pairs(package.loaded) do
  if package.searchpath(name, mine) then package.loaded[name] = nil end
end
if not package.path:find(mine, 1, true) then package.path = mine .. ";" .. package.path end
local probe = require("probe")

local function key(n)
  return table.concat({ n.spelling, tostring(n.pos), n.grace and "" or tostring(n.duration), n.grace and "g" or "n" },
    "|")
end

probe.run("verify_sample", function(p)
  local dumpparse = require("dumpparse")
  local json = require("json")
  local f = assert(io.open(here .. "expected.json", "rb"))
  local expected = json.decode(f:read("*a"))
  f:close()
  local app = DoApp.DoApp()
  local score = app.currentScore
  p:check("two flows", #score.flows == #expected.flows, #score.flows)

  for i, want in ipairs(expected.flows) do
    local flow = score.flows[i]
    if flow then
      local owners = dumpparse.owners(score, flow)
      local got = {}
      for _, s in ipairs(flow.voiceStreams) do
        local name = owners[s.id] or "?"
        got[name] = got[name] or {}
        for _, ev in ipairs(dumpparse.parse(s:dump()).events) do
          if ev.kind == "note" or ev.kind == "grace" then
            got[name][#got[name] + 1] = key({ spelling = ev.spelling, pos = ev.pos, duration = ev.duration,
              grace = ev.kind == "grace" })
          end
        end
      end
      for _, player in ipairs(want.players) do
        local wantKeys = {}
        for _, n in ipairs(player.notes) do wantKeys[#wantKeys + 1] = key(n) end
        local gotKeys = got[player.name] or {}
        table.sort(wantKeys)
        table.sort(gotKeys)
        p:check("flow " .. i .. " " .. player.name, table.concat(wantKeys, " ") == table.concat(gotKeys, " "),
          "want " .. table.concat(wantKeys, " ") .. " | got " .. table.concat(gotKeys, " "))
      end
    end
  end
end)
