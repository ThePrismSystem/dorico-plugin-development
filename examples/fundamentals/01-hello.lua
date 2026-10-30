-- Hello, Dorico: the smallest script that reads something, laid out the way every example here is.
-- What it does: prints Dorico's version, the project's title, and how many flows and players it has.
-- Changes: nothing (read-only).
-- Undo: nothing to undo.
-- Builds on: nothing. Run it with Script > Run Script, then open Script > Show Script Console to read what it
-- printed. The console keeps lines printed while it was closed.

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

-- Dorico runs every script in one Lua state that lasts until it quits, so a global set here would still be there on
-- the next run. Keeping everything local means each run starts clean.
local app, score = guard()
if not score then return end

print("Dorico " .. app.versionString)
print("project: " .. tostring(score.title))
print("flows: " .. #score.flows)
print("players: " .. #score.players)
