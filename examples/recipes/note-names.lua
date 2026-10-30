-- Write each note's name under it, for teaching: letter names, German names, fixed or movable do, or scale degrees.
-- What it does: reads a saved copy, asks for the naming system and where the names go, then writes one staff text per
-- note, or per chord with its names stacked top first, in the players and flows chosen. Transposing instruments get
-- their written notes' names unless you untick that. Tick "Only remove names" to take the names off and add none.
-- Changes: adds a staff text at each note, and in those players and flows deletes each text that reads as the names
-- of the chord under it, as an earlier run wrote them, which takes a text you typed that reads that way too.
-- Undo: Edit > Undo takes the whole run back in one step.
-- Builds on: 04-read-the-saved-copy.lua, 09-bars-keys-and-times.lua (key signatures), 13-set-a-property-by-id.lua,
-- 14-add-notes-rests-text.lua and 17-ask-and-report.lua (the form helper). Open Script > Show Script Console to read
-- what it prints.
--
-- A tied note is one note, so it gets one name. Grace notes get none. Accidentals come from each note's own spelling,
-- and movable do and scale degrees follow the key signature in force at the note, in the written key when the names
-- are for written pitch (movable do keeps the major key's do in a minor key). Under an atonal key signature, or one
-- the reader can't give the fifths of, movable do and scale degrees name nothing, and the run says how many notes
-- that left. A name is an ordinary staff text, so a run first deletes, in the players and flows chosen, every text in
-- a voice that sits on a note or chord and has a line for each of its notes, every line a name this script could
-- write for some note: a letter name, a solfa syllable or a scale degree, with or without an octave. A text you typed
-- that reads that way goes too. Writing a text takes about 60 ms, so a long score takes a while.

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

-- helper: readCopy
-- Reads a saved copy of the open project with the reader library, or prints why it couldn't and gives nil. The
-- library is lib/ two folders up in this repository, or a lib folder beside the script once both are copied into
-- Script Plug-ins. Dorico keeps one Lua state, so the library's modules from an earlier run are cleared, and its
-- folders are moved to the front of the module path, where no other copy of the library can come before them. The
-- library loads outside the pcall, so a missing or broken library isn't reported as a project it couldn't read.
local function readCopy(app)
  local here = debug.getinfo(1, "S").source:match("^@(.*[/\\])") or ""
  local paths = here .. "../../lib/?.lua;" .. here .. "lib/?.lua;"
  for name in pairs(package.loaded) do
    if name:match("^scorereader") then package.loaded[name] = nil end
  end
  local at = package.path:find(paths, 1, true)
  if at then package.path = package.path:sub(1, at - 1) .. package.path:sub(at + #paths) end
  package.path = paths .. package.path
  if package.searchpath("scorereader.dorico.savedcopy", package.path) then
    local savedcopy = require("scorereader.dorico.savedcopy")
    local ok, s = pcall(savedcopy.read, app)
    if ok then return s end
    print("The reader couldn't read this project: " .. tostring(s))
  else
    print("Couldn't find the reader library: copy the lib folder beside this script, then run it again.")
  end
end
-- end helper: readCopy

-- helper: form
-- A box with a row per option, to ask before a script changes anything, so that Cancel leaves nothing to undo. Each
-- field is a text box, a tick box or a list to choose from, with a default, so OK with nothing changed runs on the
-- defaults. The Windows box is topmost so it can't open behind Dorico's window, and it writes one "key=value" line
-- per field as UTF-8, so accented letters survive; Cancel writes an empty answer. The Mac route asks one question at
-- a time.
--   form.ask(title, fields) -> {[key] = text, or true or false for a tick box}; nil on Cancel; nil and the reason
--     when no box could be shown; fields: {{key, label, kind = "text" | "check" | "choice", default, choices = {...}}}
--   form.windows(title, fields, folder) and form.mac(title, fields): the two routes form.ask picks between
--   form.script(title, fields) -> the PowerShell
--   form.parse(text, fields) -> the answers; nil for no answer; nil and the reason for an answer that leaves out a
--     field or gives a choice the list doesn't offer
local form = {}
do
  -- A PowerShell single-quoted string doubles its quotes. PowerShell also takes the curly single quotes (U+2018 to
  -- U+201B) as quotes, and a project's titles and names can hold them. An AppleScript string escapes quotes and
  -- backslashes.
  local function ps(s) return "'" .. (tostring(s):gsub("'", "''"):gsub("\226\128[\152-\155]", "%0%0")) .. "'" end
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
        -- Windows draws a System-style tick box itself, so another program can read and set its state.
        add("$c = New-Object System.Windows.Forms.CheckBox")
        add("$c.FlatStyle = 'System'")
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
      "  $text = $lines -join [char]10",
      "} else { $text = '' }",
      "[System.IO.File]::WriteAllText($Out, $text, (New-Object System.Text.UTF8Encoding $false))",
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
      if value == nil then return nil, "its answer left out " .. f.key end
      if f.kind == "check" then value = value:lower() == "true" end
      if f.kind == "choice" then
        local offered = false
        for _, choice in ipairs(f.choices) do offered = offered or choice == value end
        if not offered then
          return nil, string.format("its answer for %s, \"%s\", isn't one of the choices", f.label, value)
        end
      end
      answers[f.key] = value
    end
    return answers
  end

  -- Windows paths take forward slashes too, which keeps the folder's own backslashes out of the command line.
  function form.windows(title, fields, folder)
    local script, answer = folder .. "/dorico-form.ps1", folder .. "/dorico-form.txt"
    -- A last answer left in place would be read as this box's if PowerShell then wrote none, so no box is shown
    -- unless it has gone. os.remove's third result is the error number, and 2 means there was no file to delete.
    local gone, _, code = os.remove(answer)
    if not gone and code ~= 2 then return nil, "couldn't delete the last answer, " .. answer end
    local f = io.open(script, "wb")
    if not f then return nil, "couldn't write " .. script end
    -- Windows PowerShell 5.1 reads a script with no byte order mark in the ANSI code page, which garbles accents.
    f:write("\239\187\191" .. form.script(title, fields))
    f:close()
    os.execute('powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "' .. script .. '" -Out "'
      .. answer .. '"')
    local text = readFile(answer)
    os.remove(script)
    os.remove(answer)
    -- Cancel writes an empty answer, so no answer at all means PowerShell didn't run the box to the end.
    if not text then return nil, "PowerShell gave no answer" end
    if text == "" then return nil end
    return form.parse(text, fields)
  end

  -- Not run on a Mac. Each answer comes back after "ok:", so an empty answer can be told from Cancel, which
  -- AppleScript reports as error -128. Any other output is why osascript failed.
  function form.mac(title, fields)
    local answers = {}
    for _, f in ipairs(fields) do
      local lines
      if f.kind == "check" then
        -- A Cancel button, named as the cancel button, raises -128 as the other questions' Cancel does.
        lines = { '"ok:" & button returned of (display dialog ' .. apple(f.label)
          .. ' buttons {"Cancel", "No", "Yes"} default button ' .. apple(f.default and "Yes" or "No")
          .. ' cancel button "Cancel" with title ' .. apple(title) .. ")" }
      elseif f.kind == "choice" then
        local items = {}
        for _, choice in ipairs(f.choices) do items[#items + 1] = apple(choice) end
        -- choose from list gives false on Cancel where display dialog raises -128, so it's made to raise it too.
        lines = { "set r to choose from list {" .. table.concat(items, ", ") .. "} with prompt " .. apple(f.label)
          .. " default items {" .. apple(f.default) .. "} with title " .. apple(title),
          "if r is false then error number -128", '"ok:" & item 1 of r' }
      else
        lines = { '"ok:" & text returned of (display dialog ' .. apple(f.label) .. " default answer "
          .. apple(f.default or "") .. " with title " .. apple(title) .. ")" }
      end
      local command = "osascript"
      for _, line in ipairs(lines) do command = command .. " -e '" .. line:gsub("'", "'\\''") .. "'" end
      local p, err = io.popen(command .. " 2>&1")
      if not p then return nil, "couldn't start osascript: " .. tostring(err) end
      local text = p:read("*a")
      p:close()
      local value = text:match("^ok:(.-)\r?\n?$")
      if not value then
        if text:find("(-128)", 1, true) then return nil end
        local why = text:match("^%s*(.-)%s*$")
        return nil, why ~= "" and why or "osascript gave no answer"
      end
      if f.kind == "check" then value = value == "Yes" end
      answers[f.key] = value
    end
    return answers
  end

  function form.ask(title, fields)
    if package.config:sub(1, 1) == "\\" then
      local folder = os.getenv("TEMP") or os.getenv("TMP")
      if not folder then return nil, "neither TEMP nor TMP names a folder" end
      return form.windows(title, fields, folder)
    end
    return form.mac(title, fields)
  end
end
-- end helper: form

-- helper: names
-- Note names from spellings in the reader's form ("F#5", "Eb4", "Dx4"), with sharps and flats as music symbols.
--   names.of(spelling, system, opts) -> the name; system is "english", "german", "fixed-it", "fixed-fr", "fixed-es",
--     "movable" or "degrees"; opts.octave adds the octave number, opts.key = {fifths, mode} is the key for movable do
--     and degrees (C major when there is none)
--   names.chord(spellings, system, opts) -> the names of a chord's notes, one per line, highest first
--   names.written(spelling, transposition) -> the written spelling, transposition = {diatonic, chromatic} as the
--     reader gives an instrument's (nil for none)
--   names.writtenKey(key, transposition) -> the key the instrument's part is written in, for written names
--   names.isName(words) -> whether every line of words is a name this helper could give one note, in any system and
--     key, with or without its octave
local names = {}
do
  local LETTERS = "CDEFGAB"
  local NATURAL = { 0, 2, 4, 5, 7, 9, 11 }
  local SHARP, FLAT = "\226\153\175", "\226\153\173"
  local FIXED = {
    ["fixed-it"] = { "Do", "Re", "Mi", "Fa", "Sol", "La", "Si" },
    ["fixed-fr"] = { "Do", "R\195\169", "Mi", "Fa", "Sol", "La", "Si" },
    ["fixed-es"] = { "Do", "Re", "Mi", "Fa", "Sol", "La", "Si" },
  }
  local MOVABLE = { "do", "re", "mi", "fa", "sol", "la", "ti" }
  local RAISED = { "di", "ri", nil, "fi", "si", "li", nil }
  local LOWERED = { "de", "ra", "me", "fe", "se", "le", "te" }
  -- An alteration in a spelling: "#", "x" for a double sharp, "b" for each flat.
  local function spelled(alter)
    return alter > 0 and (alter == 2 and "x" or string.rep("#", alter)) or string.rep("b", -alter)
  end

  -- The tonic of the key with this many fifths (sharps above 0, flats below), spelled without an octave: 0 is C major
  -- or A minor, and a written key can go past seven, as 8 for G# major.
  local function tonicOf(fifths, minor)
    local f = fifths + (minor and 3 or 0) + 1
    return ("FCGDAEB"):sub(f % 7 + 1, f % 7 + 1) .. spelled(math.floor(f / 7))
  end
  local SCALES = { major = { 0, 2, 4, 5, 7, 9, 11 }, minor = { 0, 2, 3, 5, 7, 8, 10 } }

  -- letter index 1 to 7, alteration in semitones, octave
  local function parse(spelling)
    local letter, accidentals, octave = spelling:match("^([A-G])([#bx]*)(%-?%d+)$")
    if not letter then error("not a spelling: " .. tostring(spelling), 2) end
    local alter = 0
    for c in accidentals:gmatch(".") do alter = alter + (c == "#" and 1 or c == "x" and 2 or -1) end
    return LETTERS:find(letter), alter, tonumber(octave)
  end

  -- The MIDI pitch of a parsed spelling.
  local function pitchOf(i, alter, octave)
    return 12 * (octave + 1) + NATURAL[i] + alter
  end

  local function symbols(alter)
    return string.rep(alter > 0 and SHARP or FLAT, math.abs(alter))
  end

  local function german(i, alter)
    local base = ({ "C", "D", "E", "F", "G", "A", "H" })[i]
    if alter > 0 then return base .. string.rep("is", alter) end
    if alter == 0 then return base end
    if i == 7 then return alter == -1 and "B" or "Heses" end
    local flat = (i == 3 or i == 6) and (base .. "s") or (base .. "es")
    return alter == -1 and flat or (flat .. "es")
  end

  -- The note's step above the tonic (1 to 7) and how far it is from that step of the scale.
  local function degree(i, alter, tonic, scale)
    local ti, talter = parse(tonic .. "4")
    local step = (i - ti) % 7 + 1
    local pc = (NATURAL[i] + alter) % 12
    local expected = (NATURAL[ti] + talter + scale[step]) % 12
    return step, (pc - expected + 6) % 12 - 6
  end

  function names.of(spelling, system, opts)
    opts = opts or {}
    local i, alter, octave = parse(spelling)
    local key = opts.key or { fifths = 0, mode = "major" }
    local name
    if system == "german" then
      name = german(i, alter)
    elseif FIXED[system] then
      name = FIXED[system][i] .. symbols(alter)
    elseif system == "movable" then
      local step, off = degree(i, alter, tonicOf(key.fifths), SCALES.major)
      name = (off == 1 and RAISED[step]) or (off == -1 and LOWERED[step]) or (MOVABLE[step] .. symbols(off))
    elseif system == "degrees" then
      local minor = key.mode == "minor"
      local step, off = degree(i, alter, tonicOf(key.fifths, minor), minor and SCALES.minor or SCALES.major)
      name = symbols(off) .. step
    else
      name = spelling:sub(1, 1) .. symbols(alter)
    end
    if opts.octave then name = name .. octave end
    return name
  end

  function names.chord(spellings, system, opts)
    local sorted = {}
    for k, sp in ipairs(spellings) do
      sorted[k] = { sp = sp, pitch = pitchOf(parse(sp)) }
    end
    table.sort(sorted, function(a, b) return a.pitch > b.pitch end)
    local out = {}
    for k, n in ipairs(sorted) do out[k] = names.of(n.sp, system, opts) end
    return table.concat(out, "\n")
  end

  function names.written(spelling, transposition)
    if not transposition then return spelling end
    local i, alter, octave = parse(spelling)
    local pitch = pitchOf(i, alter, octave) + transposition.chromatic
    local steps = i - 1 + transposition.diatonic
    local wi, wo = steps % 7 + 1, octave + math.floor(steps / 7)
    return LETTERS:sub(wi, wi) .. spelled(pitch - pitchOf(wi, 0, wo)) .. wo
  end

  -- A transposition moves the key by 7 fifths for each semitone and back 12 for each letter step: a major second up
  -- (1 step, 2 semitones) is 2 fifths, so concert C is written in D.
  function names.writtenKey(key, transposition)
    if not key or not transposition then return key end
    return { fifths = key.fifths + 7 * transposition.chromatic - 12 * transposition.diatonic, mode = key.mode }
  end

  local known
  function names.isName(words)
    if not known then
      known = {}
      for i = 1, 7 do
        for alter = -2, 2 do
          local spelling = LETTERS:sub(i, i) .. spelled(alter) .. "4"
          for _, system in ipairs({ "english", "german", "fixed-it", "fixed-fr", "fixed-es", "movable", "degrees" }) do
            for fifths = -7, 7 do
              for _, mode in ipairs({ "major", "minor" }) do
                known[names.of(spelling, system, { key = { fifths = fifths, mode = mode } })] = true
              end
            end
          end
        end
      end
    end
    if words == "" then return false end
    for line in (words .. "\n"):gmatch("([^\n]*)\n") do
      local ok = known[line] == true
      for k = 1, #line - 1 do
        ok = ok or (known[line:sub(1, k)] == true and line:sub(k + 1):match("^%-?%d+$") ~= nil)
      end
      if not ok then return false end
    end
    return true
  end
end
-- end helper: names

local TITLE = "Note names"
local SYSTEMS = {
  { "English (C, D, E)", "english" }, { "German (C, D, E, H)", "german" }, { "Fixed do (Italian)", "fixed-it" },
  { "Fixed do (French)", "fixed-fr" }, { "Fixed do (Spanish)", "fixed-es" }, { "Movable do", "movable" },
  { "Scale degrees", "degrees" },
}
local ALL_PLAYERS, ALL_FLOWS = "All players", "All flows"

local app, project = guard()
if not project then return end
local s = readCopy(app)
if not s then return end
local commands = require("scorereader.dorico.commands")
local edit = require("scorereader.dorico.edit")
local values = require("scorereader.values")

local systemLabels, playerLabels, flowLabels = {}, { ALL_PLAYERS }, { ALL_FLOWS }
for _, sys in ipairs(SYSTEMS) do systemLabels[#systemLabels + 1] = sys[1] end
for _, player in ipairs(s.players) do playerLabels[#playerLabels + 1] = player.name end
for n, flow in ipairs(s.flows) do flowLabels[#flowLabels + 1] = n .. ": " .. flow.title end

-- Ask before changing anything, so that Cancel leaves nothing to undo.
local answers, noBox = form.ask(TITLE, {
  { key = "system", label = "Names", kind = "choice", default = systemLabels[1], choices = systemLabels },
  { key = "place", label = "Where", kind = "choice", default = "Below the staff",
    choices = { "Below the staff", "Above the staff" } },
  { key = "octave", label = "Octave numbers", kind = "check", default = false },
  { key = "written", label = "Written pitch", kind = "check", default = true },
  { key = "player", label = "Players", kind = "choice", default = ALL_PLAYERS, choices = playerLabels },
  { key = "flow", label = "Flows", kind = "choice", default = ALL_FLOWS, choices = flowLabels },
  { key = "remove", label = "Only remove names", kind = "check", default = false },
})
if not answers then
  print(noBox and "The box didn't work: " .. noBox or "Cancelled: nothing changed.")
  return
end
local system
for _, sys in ipairs(SYSTEMS) do
  if sys[1] == answers.system then system = sys[2] end
end

-- A flow's key signatures in order, as {pos, key}: key is {fifths, mode} for the names helper, or false for an atonal
-- key or one with no fifths the reader could give, such as a custom key.
local function keysOf(flow)
  local keys = {}
  for _, e in ipairs(flow.events) do
    if e.kind == "keySignature" then
      keys[#keys + 1] = { pos = values.toNumber(e.position),
        key = e.fifths ~= nil and { fifths = e.fifths, mode = e.mode == "minor" and "minor" or "major" } }
    end
  end
  table.sort(keys, function(a, b) return a.pos < b.pos end)
  return keys
end

-- The key in force at a position, from keysOf: nil before the first key signature, which the names helper takes as
-- C major.
local function keyAt(keys, pos)
  local key
  for _, k in ipairs(keys) do
    if k.pos <= pos then key = k.key else break end
  end
  return key
end

local function lineCount(words)
  return select(2, words:gsub("\n", "")) + 1
end

-- Deleting goes through a selection, which needs Write mode outside note input.
app:doCommand("NoteInput.Exit")
app:doCommand(commands.build("Window.SwitchMode", { { "WindowMode", "kWriteMode" } }))

local playerIds = {}
for _, player in ipairs(s.players) do
  if answers.player == ALL_PLAYERS or answers.player == player.name then playerIds[player.id] = true end
end

-- In the flows and players asked for, gather each voice's chords, {stream, position, key, notes = {events}}, and take
-- off every name an earlier run could have written: a text that reads as names, one line for each note of the chord
-- at its position.
local removed, chords = 0, {}
for n, flow in ipairs(s.flows) do
  if answers.flow == ALL_FLOWS or answers.flow == flowLabels[n + 1] then
    local keys = keysOf(flow)
    for _, stream in ipairs(flow.streams) do
      if stream.type == "voice" and playerIds[stream.playerId] then
        local at, texts = {}, {}
        for _, e in ipairs(stream.events) do
          local pos = values.positionText(e.position)
          if e.kind == "note" then
            if not at[pos] then
              at[pos] = { stream = stream, position = e.position, key = keyAt(keys, values.toNumber(e.position)),
                notes = {} }
              chords[#chords + 1] = at[pos]
            end
            table.insert(at[pos].notes, e)
          elseif e.kind == "text" and names.isName(e.words) then
            texts[#texts + 1] = e
          end
        end
        for _, e in ipairs(texts) do
          local chord = at[values.positionText(e.position)]
          if chord and lineCount(e.words) == #chord.notes then
            edit.delete(app, e)
            removed = removed + 1
          end
        end
      end
    end
  end
end
if answers.remove then
  print(string.format("Removed %d names.", removed))
  return
end

-- Lua's flow and stream objects, by id, to write into.
local streams = {}
for _, flow in ipairs(app.currentScore.flows) do
  for _, stream in ipairs(flow.voiceStreams) do streams[stream.id] = stream end
end

-- Movable do and scale degrees name a note by its place in the key, so a note with no key it can read gets no name.
local needsKey = system == "movable" or system == "degrees"
local made, keyless = {}, 0
for _, chord in ipairs(chords) do
  if needsKey and chord.key == false then
    keyless = keyless + 1
  else
    local t = answers.written and (s.instruments[chord.stream.instrumentId] or {}).transposition
    local spellings = {}
    for k, e in ipairs(chord.notes) do spellings[k] = names.written(e.spelling, t) end
    local words = names.chord(spellings, system,
      { octave = answers.octave, key = names.writtenKey(chord.key or nil, t) })
    local p = chord.position
    local text = streams[chord.stream.id]:createText(DoCore.RhythmicLength(p.num, p.den), DoCore.RhythmicLength(1),
      words)
    made[#made + 1] = text.id
  end
end

-- A new text goes above the staff. Setting kTextEventAboveOrBelow by id moves it below in every layout, and the
-- command needs the block id that only a saved copy gives.
local stayed, why = 0, nil
if answers.place == "Below the staff" and #made > 0 then
  local after = readCopy(app)
  for _, id in ipairs(made) do
    if after and after.events[id] then
      edit.setProperty(app, after.events[id], "kTextEventAboveOrBelow", "kBelow")
    else
      stayed = stayed + 1
    end
  end
  why = after and "they weren't in the project read back" or "the project couldn't be read back to move them"
end
print(string.format("Wrote %d names; removed %d old ones.", #made, removed))
if keyless > 0 then
  print(string.format("Left %d notes or chords unnamed: %s needs a key, and the key signature there is atonal or one "
    .. "this script can't read.", keyless, answers.system))
end
if stayed > 0 then print(string.format("%d of them stayed above the staff: %s.", stayed, why)) end
