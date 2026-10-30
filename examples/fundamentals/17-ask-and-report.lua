-- Ask the user something, then act on the answer: here, a word or phrase to put in a new flow.
-- What it does: shows a box asking "What should the new flow say?". On OK it adds a flow at the end, titled with
-- the answer, with the answer as a staff text at its start, and prints what it did. On Cancel, or with nothing
-- typed, it changes nothing.
-- Changes: adds a flow, with one staff text in it.
-- Undo: Edit > Undo takes the new flow away, and the text in it goes with it.
-- Builds on: 10-commands.lua and 14-add-notes-rests-text.lua. Open Script > Show Script Console to read what it
-- prints.
--
-- Lua in Dorico has no dialogs of its own, but it can start a program and wait for it. The form helper below asks
-- for any number of options, each a text box, a tick box or a list to choose from; this script asks for one. On
-- Windows it writes a small PowerShell script into the temporary folder and runs it with os.execute; PowerShell shows
-- a Windows Forms box and writes the answers to a file, which the script reads back. Dorico waits while the box is
-- open. On a Mac it asks one question at a time through osascript. The Mac route is written from Apple's
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

-- helper: form
-- A box with a row per option, to ask before a script changes anything, so that Cancel leaves nothing to undo. Each
-- field is a text box, a tick box or a list to choose from, with a default, so OK with nothing changed runs on the
-- defaults. The Windows box is topmost so it can't open behind Dorico's window, and it writes one "key=value" line
-- per field as UTF-8, so accented letters survive; Cancel writes nothing. The Mac route asks one question at a time.
--   form.ask(title, fields) -> {[key] = text, or true or false for a tick box}, or nil on Cancel or when no box
--     could be shown; fields: {{key, label, kind = "text" | "check" | "choice", default, choices = {...}}}
--   form.windows(title, fields, folder) and form.mac(title, fields): the two routes form.ask picks between
--   form.script(title, fields) -> the PowerShell; form.parse(text, fields) -> the answers, or nil for none
local form = {}
do
  -- A PowerShell single-quoted string doubles its quotes; an AppleScript string escapes quotes and backslashes.
  local function ps(s) return "'" .. (tostring(s):gsub("'", "''")) .. "'" end
  local function apple(s) return '"' .. (tostring(s):gsub("\\", "\\\\"):gsub('"', '\\"')) .. '"' end

  local function readFile(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local text = f:read("*a")
    f:close()
    return text
  end

  function form.script(title, fields)
    local bottom = 12 + 32 * #fields
    local out = {
      "param([string]$Out)",
      "Add-Type -AssemblyName System.Windows.Forms, System.Drawing",
      "$form = New-Object System.Windows.Forms.Form",
      "$form.Text = " .. ps(title),
      "$form.TopMost = $true",
      "$form.StartPosition = 'CenterScreen'",
      "$form.FormBorderStyle = 'FixedDialog'",
      "$form.MaximizeBox = $false",
      "$form.MinimizeBox = $false",
      string.format("$form.ClientSize = New-Object System.Drawing.Size(452, %d)", bottom + 46),
      "$fields = @()",
    }
    local function add(line) out[#out + 1] = line end
    for i, f in ipairs(fields) do
      local y = 12 + 32 * (i - 1)
      add("$label = New-Object System.Windows.Forms.Label")
      add("$label.Text = " .. ps(f.label))
      add("$label.UseMnemonic = $false")
      add(string.format("$label.SetBounds(12, %d, 200, 24)", y + 3))
      add("$form.Controls.Add($label)")
      if f.kind == "check" then
        add("$c = New-Object System.Windows.Forms.CheckBox")
        add("$c.Checked = $" .. tostring(f.default == true))
      elseif f.kind == "choice" then
        local items = {}
        for _, choice in ipairs(f.choices) do items[#items + 1] = ps(choice) end
        add("$c = New-Object System.Windows.Forms.ComboBox")
        add("$c.DropDownStyle = 'DropDownList'")
        add("[void]$c.Items.AddRange(@(" .. table.concat(items, ", ") .. "))")
        add("$c.SelectedItem = " .. ps(f.default))
      else
        add("$c = New-Object System.Windows.Forms.TextBox")
        add("$c.Text = " .. ps(f.default or ""))
      end
      add(string.format("$c.SetBounds(220, %d, 220, 24)", y))
      add("$form.Controls.Add($c)")
      add("$fields += ,@(" .. ps(f.key) .. ", $c)")
    end
    for _, line in ipairs({
      "$ok = New-Object System.Windows.Forms.Button",
      "$ok.Text = 'OK'",
      "$ok.DialogResult = 'OK'",
      string.format("$ok.SetBounds(284, %d, 75, 26)", bottom + 8),
      "$cancel = New-Object System.Windows.Forms.Button",
      "$cancel.Text = 'Cancel'",
      "$cancel.DialogResult = 'Cancel'",
      string.format("$cancel.SetBounds(365, %d, 75, 26)", bottom + 8),
      "$form.Controls.AddRange(@($ok, $cancel))",
      "$form.AcceptButton = $ok",
      "$form.CancelButton = $cancel",
      "if ($form.ShowDialog() -eq 'OK') {",
      "  $lines = foreach ($f in $fields) {",
      "    $c = $f[1]",
      "    if ($c -is [System.Windows.Forms.CheckBox]) { $v = $c.Checked }",
      "    elseif ($c -is [System.Windows.Forms.ComboBox]) { $v = $c.SelectedItem }",
      "    else { $v = $c.Text }",
      "    $f[0] + '=' + $v",
      "  }",
      "  [System.IO.File]::WriteAllText($Out, ($lines -join [char]10), (New-Object System.Text.UTF8Encoding $false))",
      "}",
    }) do add(line) end
    return table.concat(out, "\r\n") .. "\r\n"
  end

  function form.parse(text, fields)
    if not text or text == "" then return nil end
    local got = {}
    for line in text:gmatch("[^\r\n]+") do
      local key, value = line:match("^([^=]+)=(.*)$")
      if key then got[key] = value end
    end
    local answers = {}
    for _, f in ipairs(fields) do
      local value = got[f.key]
      if value == nil then return nil end
      if f.kind == "check" then value = value:lower() == "true" end
      answers[f.key] = value
    end
    return answers
  end

  -- Windows paths take forward slashes too, which keeps the folder's own backslashes out of the command line.
  function form.windows(title, fields, folder)
    local script, answer = folder .. "/dorico-form.ps1", folder .. "/dorico-form.txt"
    local f = io.open(script, "wb")
    if not f then return nil end
    f:write(form.script(title, fields))
    f:close()
    os.remove(answer)
    os.execute('powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "' .. script .. '" -Out "'
      .. answer .. '"')
    local text = readFile(answer)
    os.remove(script)
    os.remove(answer)
    return form.parse(text, fields)
  end

  -- Not run on a Mac. Each answer comes back after "ok:", so an empty answer can be told from Cancel, which makes
  -- osascript fail with no output.
  function form.mac(title, fields)
    local answers = {}
    for _, f in ipairs(fields) do
      local ask
      if f.kind == "check" then
        ask = "button returned of (display dialog " .. apple(f.label) .. ' buttons {"No", "Yes"} default button '
          .. apple(f.default and "Yes" or "No") .. " with title " .. apple(title) .. ")"
      elseif f.kind == "choice" then
        local items = {}
        for _, choice in ipairs(f.choices) do items[#items + 1] = apple(choice) end
        ask = "item 1 of (choose from list {" .. table.concat(items, ", ") .. "} with prompt " .. apple(f.label)
          .. " default items {" .. apple(f.default) .. "} with title " .. apple(title) .. ")"
      else
        ask = "text returned of (display dialog " .. apple(f.label) .. " default answer " .. apple(f.default or "")
          .. " with title " .. apple(title) .. ")"
      end
      local p = io.popen("osascript -e '\"ok:\" & " .. ask:gsub("'", "'\\''") .. "' 2>/dev/null")
      local text = p:read("*a")
      p:close()
      local value = text:match("^ok:(.-)\r?\n?$")
      if not value then return nil end
      if f.kind == "check" then value = value == "Yes" end
      answers[f.key] = value
    end
    return answers
  end

  function form.ask(title, fields)
    if package.config:sub(1, 1) == "\\" then
      local folder = os.getenv("TEMP") or os.getenv("TMP")
      if not folder then return nil end
      return form.windows(title, fields, folder)
    end
    return form.mac(title, fields)
  end
end
-- end helper: form

local app, score = guard()
if not score then return end
if #score.players == 0 then
  print("Add a player first, then run this script again.")
  return
end

-- Ask before changing anything, so that Cancel leaves nothing to undo.
local answers = form.ask(TITLE, { { key = "words", label = QUESTION, kind = "text", default = "" } })
local answer = answers and answers.words
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
