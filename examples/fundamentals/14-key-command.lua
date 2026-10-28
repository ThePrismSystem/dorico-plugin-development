-- A script meant to run from a key: it counts its own runs, keeping the count between them.
-- What it does: prints "run <n> since Dorico started", where n goes up by one each time it runs.
-- Changes: nothing (read-only). It keeps one global variable, DoricoExamplesKeyCommandRuns.
-- Undo: nothing to undo.
-- Builds on: 01-hello.lua. Open Script > Show Script Console to read what it prints.
--
-- To run it from a key without any setup, start it once with Script > Run Script. From then on Ctrl+Shift+Alt+R
-- (Script > Run Last Script, Dorico's own key command) runs it again, until you run a different script.
--
-- A key of its own has to be set up by hand. This example doesn't do it, since that means editing Dorico's
-- key-command file and restarting Dorico. The user's key commands are in keycommands_en.json (one file per language)
-- in %APPDATA%\Steinberg\Dorico 6. The file appears once you change any key command in Preferences > Key Commands.
-- In its "kGlobal" context's "shortcuts" list, an entry like this binds a key to a script:
--   { "Script.RunScript?ScriptPath=C:/Users/you/Scripts/14-key-command.lua&ShowConsole=false": [ "Ctrl+Alt+K" ] }
-- Quit Dorico before editing the file, keep a copy of it, and start Dorico again afterwards. The keycommands_en.json
-- in Dorico's program folder shows the file's layout, including commands bound with parameters.
--
-- Dorico runs every script in one Lua state that lasts until it quits, so a global set by one run is still there for
-- the next. That's how this keeps its count, and why a global needs a name no other script would choose. Anything
-- that must survive Dorico quitting has to go in a file.

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

local app, score = guard()
if not score then return end

DoricoExamplesKeyCommandRuns = (DoricoExamplesKeyCommandRuns or 0) + 1
print("run " .. DoricoExamplesKeyCommandRuns .. " since Dorico started")
