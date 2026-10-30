-- Ask the user something, then act on the answer: here, a word or phrase to put in a new flow.
-- What it does: shows a box asking "What should the new flow say?". On OK it adds a flow at the end, titled with
-- the answer, with the answer as a staff text at its start, and prints what it did. On Cancel, or with nothing
-- typed, it changes nothing.
-- Changes: adds a flow, with one staff text in it.
-- Undo: Edit > Undo takes the new flow away, and the text in it goes with it.
-- Builds on: 10-commands.lua and 14-add-notes-rests-text.lua. Open Script > Show Script Console to read what it
-- prints.
--
-- Lua in Dorico has no dialogs of its own, but it can start a program and wait for it. On Windows the script writes
-- a small PowerShell script into the temporary folder and runs it with os.execute; PowerShell shows a Windows Forms
-- box and writes the answer to a file, which the script reads back. Dorico waits while the box is open. On a Mac it
-- runs osascript, which can show a "display dialog" box with a text field. The Mac route is written from Apple's
-- documentation and has not been run on a Mac.
--
-- Whatever the user types goes into a command (the flow's title) through the commands helper, so commas,
-- ampersands and backslashes in it arrive as typed.

local TITLE = "Ask and report"
local QUESTION = "What should the new flow say?"

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

-- The box, in PowerShell. It's topmost so that it can't open behind Dorico's window, and it writes the answer as
-- UTF-8 so that accented letters survive. Cancel writes nothing.
local POWERSHELL = [[
param([string]$Out)
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
$form = New-Object System.Windows.Forms.Form
$form.Text = '%s'
$form.TopMost = $true
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$form.MinimizeBox = $false
$form.ClientSize = New-Object System.Drawing.Size(340, 110)
$label = New-Object System.Windows.Forms.Label
$label.Text = '%s'
$label.SetBounds(12, 12, 316, 20)
$box = New-Object System.Windows.Forms.TextBox
$box.SetBounds(12, 36, 316, 24)
$ok = New-Object System.Windows.Forms.Button
$ok.Text = 'OK'
$ok.DialogResult = 'OK'
$ok.SetBounds(172, 72, 75, 26)
$cancel = New-Object System.Windows.Forms.Button
$cancel.Text = 'Cancel'
$cancel.DialogResult = 'Cancel'
$cancel.SetBounds(253, 72, 75, 26)
$form.Controls.AddRange(@($label, $box, $ok, $cancel))
$form.AcceptButton = $ok
$form.CancelButton = $cancel
if ($form.ShowDialog() -eq 'OK') {
  [System.IO.File]::WriteAllText($Out, $box.Text, (New-Object System.Text.UTF8Encoding $false))
}
]]

-- A PowerShell single-quoted string doubles its quotes; an AppleScript string escapes quotes and backslashes.
local function psQuote(s) return (s:gsub("'", "''")) end
local function appleQuote(s) return (s:gsub("\\", "\\\\"):gsub('"', '\\"')) end

local function readFile(path)
  local f = io.open(path, "rb")
  if not f then return nil end
  local text = f:read("*a")
  f:close()
  return text
end

local function askWindows()
  local folder = os.getenv("TEMP") or os.getenv("TMP")
  if not folder then error("there is no TEMP folder for the box's script") end
  local script, answer = folder .. "\\ask-and-report.ps1", folder .. "\\ask-and-report.txt"
  local f = assert(io.open(script, "wb"))
  f:write(string.format(POWERSHELL, psQuote(TITLE), psQuote(QUESTION)))
  f:close()
  os.remove(answer)
  os.execute('powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "' .. script .. '" -Out "'
    .. answer .. '"')
  local text = readFile(answer)
  os.remove(script)
  os.remove(answer)
  return text
end

-- Not run on a Mac. Cancel makes osascript fail, which leaves its output empty.
local function askMac()
  local command = string.format("osascript -e 'text returned of (display dialog \"%s\" default answer \"\" "
    .. "with title \"%s\")' 2>/dev/null", appleQuote(QUESTION), appleQuote(TITLE))
  local p = io.popen(command)
  local text = p:read("*a")
  p:close()
  return (text:gsub("\r?\n$", ""))
end

local app, score = guard()
if not score then return end
if #score.players == 0 then
  print("Add a player first, then run this script again.")
  return
end

-- Ask before changing anything, so that Cancel leaves nothing to undo.
local answer
if package.config:sub(1, 1) == "\\" then answer = askWindows() else answer = askMac() end
if not answer or answer == "" then
  print("Cancelled: nothing changed.")
  return
end

local before = {}
for _, flow in ipairs(score.flows) do before[flow.id] = true end
app:doCommand("Project.Flow.New")
local flow, number
for n, f in ipairs(app.currentScore.flows) do
  if not before[f.id] then flow, number = f, n end
end
if not flow then error("Project.Flow.New added no flow") end
app:doCommand(commands.build("Project.Flow.Rename", { { "FlowID", flow.id }, { "Name", answer } }))
flow.voiceStreams[1]:createText(DoCore.RhythmicLength(0), DoCore.RhythmicLength(1), answer)
print(string.format('wrote "%s" at the start of flow %d', answer, number))
