-- Recipe: a key that colours the selection, and steps to the next colour each time it's pressed again quickly.
-- What it does: colours whatever is selected with the first colour in COLOURS. Run again within WINDOW seconds, it
-- moves on to the next colour (after the last, back to the first); after a longer pause it starts again at the
-- first. It prints "colour <n> of <count>: <colour>".
-- Changes: the colour of the selection.
-- Undo: each run is one undo step, so Edit > Undo takes back one press at a time.
-- Builds on: 08-select-by-id.lua (colouring by command) and 14-key-command.lua (running from a key, and keeping state
-- in a global). Open Script > Show Script Console to read what it prints.
--
-- To use it from a key: select some notes, run it once with Script > Run Script, then press Ctrl+Shift+Alt+R (Run
-- Last Script) to run it again. 14-key-command.lua says how to give it a key of its own.
--
-- It remembers the last colour and when it ran in a global table, which lasts as long as Dorico's one Lua state. Lua's
-- os.time counts whole seconds, so "within 2 seconds" means within two or three.

local COLOURS = { "#ffe41a1c", "#ff1f78b4", "#ff4daf4a", "#ffff7f00" } -- red, blue, green, orange (#aarrggbb)
local WINDOW = 2

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

-- helper: commands
-- Builds a command string, "Name?key=value&key=value", for app:doCommand. Dorico reads a backslash in a value as an
-- escape, and a bare "&" or "," ends the value, so a value's own backslashes, ampersands and commas each get a
-- backslash in front; "=" and any other character pass as they are. A nil value is refused, since tostring would
-- send Dorico the word "nil". Only single ids have been tried in list parameters such as FlowIDArray; given several,
-- as "1,2", this would escape the commas between them.
--   commands.value(v) -> v escaped
--   commands.build(name, params) -> the command, params a list of {key, value} pairs
local commands = {}
do
  function commands.value(v)
    if v == nil then error("a command parameter has no value", 2) end
    return (tostring(v):gsub("\\", "\\\\"):gsub("&", "\\&"):gsub(",", "\\,"))
  end

  function commands.build(name, params)
    local parts = {}
    for i, kv in ipairs(params or {}) do parts[i] = kv[1] .. "=" .. commands.value(kv[2]) end
    if #parts == 0 then return name end
    return name .. "?" .. table.concat(parts, "&")
  end
end
-- end helper: commands

local app, score = guard()
if not score then return end

DoricoExamplesColourCycle = DoricoExamplesColourCycle or { index = 0, at = nil }
local state = DoricoExamplesColourCycle
local now = os.time()
if state.at and now - state.at <= WINDOW then
  state.index = state.index % #COLOURS + 1
else
  state.index = 1
end
state.at = now

-- Commands act on the selection; with nothing selected this one changes nothing.
app:doCommand(commands.build("UI.InvokePropertyChangeValue", { { "Type", "kEventColour" },
  { "Value", COLOURS[state.index] } }))
print(string.format("colour %d of %d: %s", state.index, #COLOURS, COLOURS[state.index]))
