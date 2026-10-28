-- Commands: how a script does most things, the same way Dorico's own menus and key commands do.
-- What it does: renames the first flow to "Études & Sketches (A=440)" by command, and prints the command it sent.
-- Change TITLE below to use another title.
-- Changes: the first flow's title.
-- Undo: Edit > Undo puts the old title back. All the commands a script run sends make one undo step.
-- Builds on: 01-hello.lua. Open Script > Show Script Console to read what it prints.
--
-- app:doCommand(text) runs one of Dorico's commands, written "Name?key=value&key=value". It returns nothing and
-- raises no error, even for a command Dorico doesn't know, so a script finds out whether a command worked by reading
-- the project afterwards. Most commands act on the selection, as they do when you press a key.
--
-- Dorico doesn't list its commands anywhere a script can read. Two places show their names: the key-command file
-- that comes with Dorico (keycommands_en.json in its program folder), and application.log in
-- %APPDATA%\Steinberg\Dorico 6, which records the command behind each menu item and popover you use.

local TITLE = "Études & Sketches (A=440)"

-- helper: guard
-- The app and the open project, or the app and nil when no project is open. With only the Hub showing, reading
-- app.currentScore can raise an error instead of giving nil, so the read goes through pcall.
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
-- send Dorico the word "nil".
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

-- Without the escape, Dorico would take the "&" in the title for the start of another parameter.
local command = commands.build("Project.Flow.Rename", { { "FlowID", score.flows[1].id }, { "Name", TITLE } })
app:doCommand(command)
print("sent: " .. command)
