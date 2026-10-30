-- Find words in staff text, system text, lyrics and chord symbols, and replace them where a script can.
-- What it does: reads a saved copy and asks what to find, whether to replace it, and where to look (a flow, a player,
-- a range of bars). Find lists every match (what it is, flow, bar and beat, player, the words) and selects the first.
-- Replace rebuilds each match with the new words, lists those it can't rebuild exactly, which it leaves as they are,
-- and reads the project back to list any change Dorico didn't make as asked.
-- Changes: in Replace, deletes each text or lyric it replaces and enters the new one in its place, and enters each new
-- chord symbol over the old one. Find changes nothing in the project, though it leaves note input and switches to
-- Write mode to select the first match.
-- Undo: Edit > Undo takes the whole run back in one step, except chord symbols: the chord-symbol commands make undo
-- steps of their own, so each one replaced adds presses (a run that replaced one chord symbol took two).
-- Builds on: 04-read-the-saved-copy.lua, 08-text-lyrics-chords-dynamics.lua, 09-bars-keys-and-times.lua,
-- 12-select-by-id.lua, 13-set-a-property-by-id.lua, 14-add-notes-rests-text.lua and 17-ask-and-report.lua (the form
-- helper). Open Script > Show Script Console to read what it prints.
--
-- Lua can't change a text's words, so a text is deleted and created again with createText at the same position, in
-- the same stream for a staff text and in the flow's first voice for a system text. It is put below the staff again by
-- id if it was there, and made a system text again through Edit.ChangeStaffTextToSystemText if it was one. A lyric is
-- deleted and entered again with the lyric commands on the note under it. A chord symbol is replaced by entering the
-- new one over it with the chord-symbol commands, on a note at its position; when Dorico can't read the new one, the
-- old one stays and the script lists it. Deleting and entering go through a selection, so the script leaves note
-- input and switches to Write mode before it changes anything. What can be rebuilt exactly is in the rebuild helper
-- below; the rest is listed and left. Chord symbols are matched by the names the reader gives, which it gives only to
-- plain major and minor chords and dominant sevenths, so other chord symbols aren't searched. The options for matching
-- are in the findtext helper.

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
    local f = io.open(script, "wb")
    if not f then return nil, "couldn't write " .. script end
    -- Windows PowerShell 5.1 reads a script with no byte order mark in the ANSI code page, which garbles accents.
    f:write("\239\187\191" .. form.script(title, fields))
    f:close()
    os.remove(answer)
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
        lines = { '"ok:" & button returned of (display dialog ' .. apple(f.label) .. ' buttons {"No", "Yes"}'
          .. " default button " .. apple(f.default and "Yes" or "No") .. " with title " .. apple(title) .. ")" }
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

-- helper: bars
-- Where bars start, from a flow's bar divisions, and the bar and beat of a position. Positions are quarter notes from
-- the start of the flow. A bar is numerator * 4 / denominator quarter notes long ("3+2" counts as 5). A time
-- signature partway through a bar starts a new bar there, and so does a barline-only division, keeping the time
-- signature. Where there is no length to go by (before the first time signature, or an open meter with no beats), a
-- bar runs to the next division. A flow with no time signature is one bar. A time signature's pickup makes its first
-- bar that long; that bar's beats count back from its end, so a one-beat pickup in 4/4 is on beat 4, and a pickup at
-- the start of the flow is bar 0.
--   bars.starts(divisions, endPos) -> {{bar, pos, length, offset}}; divisions: {{pos, numerator, denominator,
--     pickup}} in order, with no numerator for a barline-only division and pickup in quarter notes or nil
--   bars.at(starts, pos) -> bar, beat (from 1)
local bars = {}
do
  local function beats(numerator)
    local sum = 0
    for part in tostring(numerator):gmatch("%d+") do sum = sum + tonumber(part) end
    return sum
  end

  function bars.starts(divisions, endPos)
    local out, length = {}, nil
    local d1 = divisions[1]
    local base = (d1 and d1.pos == 0 and d1.numerator and d1.pickup and d1.pickup > 0) and -1 or 0
    local function add(pos, len, offset)
      out[#out + 1] = { bar = #out + 1 + base, pos = pos, length = len, offset = offset or 0 }
    end
    local first = d1 and d1.pos or endPos
    if first > 0 then add(0, first) end
    for i, d in ipairs(divisions) do
      if d.numerator then
        local n = beats(d.numerator) * 4 / d.denominator
        length = n > 0 and n or nil
      end
      local stop = divisions[i + 1] and divisions[i + 1].pos or endPos
      local pos = d.pos
      if length and d.numerator and d.pickup and d.pickup > 0 and pos < stop then
        add(pos, math.min(d.pickup, stop - pos), length - d.pickup)
        pos = pos + d.pickup
      end
      while pos < stop do
        local len = math.min(length or stop - pos, stop - pos)
        add(pos, len)
        pos = pos + len
      end
    end
    if #out == 0 then add(0, endPos) end
    return out
  end

  function bars.at(starts, pos)
    local found = starts[1]
    for _, b in ipairs(starts) do
      if b.pos <= pos then found = b else break end
    end
    return found.bar, pos - found.pos + 1 + found.offset
  end
end
-- end helper: bars

-- helper: findtext
-- Finding and replacing within a text's words. Plain text matches as typed, in either case unless matchCase is set
-- (case covers A to Z). With pattern set, the query is a Lua pattern (string.find's, which isn't a regular
-- expression), matched in the case written, and the replacement can use %1 to %9 for captures, %0 for the whole match
-- and %% for a percent sign. wholeWord keeps only matches with no letter or digit either side; each byte of an
-- accented letter counts as a letter. An empty query, or a match of nothing, finds nothing, and a malformed pattern
-- raises an error.
--   findtext.matches(words, query, opts) -> {{from, to}}, byte positions in order
--   findtext.replace(words, query, replacement, opts) -> the new words, and how many matches it replaced
local findtext = {}
do
  local function wordByte(words, i)
    if i < 1 or i > #words then return false end
    return words:byte(i) >= 128 or words:sub(i, i):match("%w") ~= nil
  end

  local function scan(words, query, opts)
    local out = {}
    local plain = not opts.pattern
    local hay, needle = words, query
    if plain and not opts.matchCase then hay, needle = words:lower(), query:lower() end
    -- string.find anchors "^" at the start position it is given, so an anchored pattern is tried once.
    local once = not plain and query:sub(1, 1) == "^"
    local init = 1
    while init <= #hay do
      local found = { hay:find(needle, init, plain) }
      local from, to = found[1], found[2]
      if not from then break end
      if to >= from and not (opts.wholeWord and (wordByte(words, from - 1) or wordByte(words, to + 1))) then
        out[#out + 1] = { from = from, to = to, captures = { table.unpack(found, 3) } }
        init = to + 1
      else
        init = from + 1
      end
      if once then break end
    end
    return out
  end

  function findtext.matches(words, query, opts)
    local out = {}
    for i, m in ipairs(scan(words, query, opts)) do out[i] = { from = m.from, to = m.to } end
    return out
  end

  function findtext.replace(words, query, replacement, opts)
    local parts, last, list = {}, 1, scan(words, query, opts)
    for _, m in ipairs(list) do
      local whole, new = words:sub(m.from, m.to), replacement
      if opts.pattern then
        new = replacement:gsub("%%(.)", function(c)
          local i = tonumber(c)
          if not i then return c end
          if i == 0 or (i == 1 and #m.captures == 0) then return whole end
          if m.captures[i] == nil then error("the pattern has no capture " .. i, 0) end
          return tostring(m.captures[i])
        end)
      end
      parts[#parts + 1] = words:sub(last, m.from - 1)
      parts[#parts + 1] = new
      last = m.to + 1
    end
    parts[#parts + 1] = words:sub(last)
    return table.concat(parts), #list
  end
end
-- end helper: findtext

-- helper: rebuild
-- Whether a text, lyric or chord symbol the reader found can be rebuilt with new words exactly, or why not. A text has
-- to be what createText makes, one plain paragraph in the default paragraph style, with no property but a placement
-- above or below the staff for every layout, which goes back on by id. A lyric has to be a whole word in a verse, on
-- line 1, below the staff, with no melisma line and no property, and the new one a single word. A chord symbol has to
-- have no property, and the new one has to be one word.
--   rebuild.why(e, entries, new, typed) -> nil or the reason; for a text that can be rebuilt, then "kBelow" when it
--     goes below the staff; entries are score.entries(s, e) and typed is values.typed
local rebuild = {}
do
  local function ownSettings(entries)
    if entries[1] then return "it has settings of its own (" .. entries[1].property .. ")" end
  end

  function rebuild.why(e, entries, new, typed)
    if e.kind == "text" then
      if e.formatted then return "it has formatting inside it" end
      if #e.paragraphs ~= 1 then return "it has more than one paragraph" end
      if e.paragraphs[1].style ~= "paragraph.defaulttext" then return "it is in another paragraph style" end
      local below = not e.above
      for _, x in ipairs(entries) do
        if x.property ~= "kTextEventAboveOrBelow" then return "it has settings of its own (" .. x.property .. ")" end
        if x.layout ~= -1 or x.instance ~= -1 then return "it is above or below the staff in one layout only" end
        below = typed(x.value).value == "kBelow"
      end
      if new == "" then return "the new words are empty" end
      return nil, below and "kBelow" or nil
    elseif e.kind == "lyric" then
      if e.line ~= 1 or e.syllable ~= "single" or e.lineType ~= "verse" then
        return "only a whole-word verse lyric on line 1 can be replaced"
      end
      if e.duration.num > 0 then return "it has a melisma line" end
      if e.above then return "it is above the staff" end
      local own = ownSettings(entries)
      if own then return own end
      if not new:match("^[^%s%-]+$") then return "the new lyric isn't a single word" end
      return nil
    end
    local own = ownSettings(entries)
    if own then return own end
    if not new:match("^%S+$") then return "the new chord symbol isn't one word" end
  end
end
-- end helper: rebuild

local TITLE = "Find and replace"
local ALL_FLOWS, ALL_PLAYERS = "All flows", "All players"
local PLACEMENT = "kTextEventAboveOrBelow"

local app, project = guard()
if not project then return end
local s = readCopy(app)
if not s then return end
local commands = require("scorereader.dorico.commands")
local edit = require("scorereader.dorico.edit")
local score = require("scorereader.score")
local values = require("scorereader.values")

local playerLabels, flowLabels = { ALL_PLAYERS }, { ALL_FLOWS }
for _, player in ipairs(s.players) do playerLabels[#playerLabels + 1] = player.name end
for n, flow in ipairs(s.flows) do flowLabels[#flowLabels + 1] = n .. ": " .. flow.title end

-- Ask before changing anything, so that Cancel leaves nothing to undo.
local answers, noBox = form.ask(TITLE, {
  { key = "mode", label = "Mode", kind = "choice", default = "Find", choices = { "Find", "Replace" } },
  { key = "query", label = "Find", kind = "text", default = "" },
  { key = "replacement", label = "Replace with", kind = "text", default = "" },
  { key = "matchCase", label = "Match case", kind = "check", default = false },
  { key = "wholeWord", label = "Whole words only", kind = "check", default = false },
  { key = "pattern", label = "Lua pattern", kind = "check", default = false },
  { key = "flow", label = "Flows", kind = "choice", default = ALL_FLOWS, choices = flowLabels },
  { key = "player", label = "Players", kind = "choice", default = ALL_PLAYERS, choices = playerLabels },
  { key = "from", label = "From bar (blank for the start)", kind = "text", default = "" },
  { key = "to", label = "To bar (blank for the end)", kind = "text", default = "" },
})
if not answers then
  print(noBox and "The box didn't work: " .. noBox or "Cancelled: nothing changed.")
  return
end
if answers.query == "" then
  print("Type the words to find, then run the script again.")
  return
end
local first, last = tonumber(answers.from), tonumber(answers.to)
if (answers.from ~= "" and not first) or (answers.to ~= "" and not last) then
  print("The bars must be numbers: nothing changed.")
  return
end

-- helper: barsOf
-- Where a flow's bars start, through the bars helper, from the time signatures in its timebase stream. A time
-- signature in any other stream is left out.
local function barsOf(flow)
  local divisions, endPos = {}, 0
  for _, e in ipairs(flow.events) do
    local pos = values.toNumber(e.position)
    endPos = math.max(endPos, pos + values.toNumber(e.duration))
    if e.kind == "timeSignature" and flow.streamById[e.streamId].type == "timebase" then
      divisions[#divisions + 1] = { pos = pos, numerator = e.numerator, denominator = e.denominator,
        pickup = e.pickup and values.toNumber(e.pickup) }
    end
  end
  table.sort(divisions, function(a, b) return a.pos < b.pos end)
  return bars.starts(divisions, endPos)
end
-- end helper: barsOf

-- The words of a text, lyric or chord symbol, and nil for any other event.
local function wordsOf(e)
  if e.kind == "text" then return e.words end
  if e.kind == "lyric" then return e.text end
  if e.kind == "chordSymbol" then return e.name end
end

local function kindOf(e)
  if e.kind == "lyric" then return "lyric" end
  if e.kind == "chordSymbol" then return "chord symbol" end
  return e.system and "system text" or "staff text"
end

-- Every matching text, lyric and chord symbol in the flows, players and bars asked for.
local found = {}
local ok2, err = pcall(function()
  for n, flow in ipairs(s.flows) do
    if answers.flow == ALL_FLOWS or answers.flow == flowLabels[n + 1] then
      local starts = barsOf(flow)
      for _, e in ipairs(flow.events) do
        local words = wordsOf(e)
        if words then
          local owner = score.ownerOf(s, e)
          local bar, beat = bars.at(starts, values.toNumber(e.position))
          if (answers.player == ALL_PLAYERS or (owner and owner.name == answers.player))
            and (not first or bar >= first) and (not last or bar <= last)
            and #findtext.matches(words, answers.query, answers) > 0 then
            found[#found + 1] = { e = e, flow = flow, n = n, bar = bar, beat = beat, words = words,
              who = owner and owner.name or "-" }
          end
        end
      end
    end
  end
end)
if not ok2 then
  print("The search couldn't run: " .. tostring(err) .. ". Nothing changed.")
  return
end
table.sort(found, function(a, b)
  if a.n ~= b.n then return a.n < b.n end
  local x, y = values.toNumber(a.e.position), values.toNumber(b.e.position)
  if x ~= y then return x < y end
  return a.e.id < b.e.id
end)

local function where(f)
  return string.format("%s\tflow %d\tbar %d, beat %g\t%s", kindOf(f.e), f.n, f.bar, f.beat, f.who)
end
local function shown(words) return (words:gsub("\n", " / ")) end

-- Selecting goes through EventEdit.Select, which needs Write mode and no note input.
local function toWriteMode()
  app:doCommand("NoteInput.Exit")
  app:doCommand(commands.build("Window.SwitchMode", { { "WindowMode", "kWriteMode" } }))
end

if answers.mode == "Find" then
  for _, f in ipairs(found) do print(where(f) .. "\t" .. shown(f.words)) end
  if #found == 0 then
    print("Found nothing.")
    return
  end
  toWriteMode()
  edit.select(app, found[1].e)
  print(string.format("Found %d; the first is selected.", #found))
  return
end

-- A note in a stream at a position, and the first note at a position in any voice of a flow.
local function noteIn(flow, streamId, pos)
  for _, e in ipairs(flow.events) do
    if e.kind == "note" and (not streamId or e.streamId == streamId)
      and values.positionText(e.position) == values.positionText(pos) then
      return e
    end
  end
end

-- Why an item can't be replaced, or nil when it can, with the note to enter a lyric or chord symbol on and the
-- placement to put a text back in.
local function check(f, new)
  local why, placement = rebuild.why(f.e, score.entries(s, f.e), new, values.typed)
  if why then return why end
  f.placement = placement
  if f.e.kind == "lyric" then
    f.note = noteIn(f.flow, f.e.streamId, f.e.position)
    if not f.note then return "there is no note under it" end
  elseif f.e.kind == "chordSymbol" then
    f.note = noteIn(f.flow, nil, f.e.position)
    if not f.note then return "there is no note at its position to enter it on" end
  end
end

-- Work out every change before making any, so a pattern that fails changes nothing.
local ok3, err3 = pcall(function()
  for _, f in ipairs(found) do
    f.new = findtext.replace(f.words, answers.query, answers.replacement, answers)
    f.why = check(f, f.new)
  end
end)
if not ok3 then
  print("The replacement couldn't be worked out: " .. tostring(err3) .. ". Nothing changed.")
  return
end

-- Lua's streams by id, to write into.
local streams, firstVoice = {}, {}
for _, flow in ipairs(app.currentScore.flows) do
  for _, stream in ipairs(flow.allStreams) do streams[stream.id] = stream end
  firstVoice[flow.id] = flow.voiceStreams[1]
end

local todo = false
for _, f in ipairs(found) do todo = todo or not f.why end
if todo then toWriteMode() end

for _, f in ipairs(found) do
  local e = f.e
  if not f.why then
    if e.kind == "text" then
      local stream = e.system and firstVoice[e.flowId] or streams[e.streamId]
      edit.delete(app, e)
      f.made = stream:createText(DoCore.RhythmicLength(e.position.num, e.position.den), DoCore.RhythmicLength(0),
        f.new).id
    else
      -- Entering a lyric doesn't replace the one already there, so the old one comes off first; a new chord symbol
      -- replaces the old one.
      if e.kind == "lyric" then edit.delete(app, e) end
      edit.select(app, f.note)
      if e.kind == "lyric" then
        app:doCommand("NoteInput.StartLyricInput")
        app:doCommand(commands.build("NoteInput.AcceptCurrentLyricInput",
          { { "LyricsEntryAdvanceType", "kEndInput" }, { "LyricText", f.new } }))
      else
        app:doCommand("NoteInput.StartChordSymbolInput")
        app:doCommand(commands.build("NoteInput.AcceptCurrentChordSymbolTextInput",
          { { "Definition", f.new }, { "ChordSymbolEntryAdvanceType", "kEndInput" } }))
      end
    end
  end
end

-- The commands need a new text's block id as well as its id, and only a saved copy gives that, so placements and
-- system texts go on after a read. The same read checks every change: the old item should be gone and the new one at
-- its position. A chord symbol Dorico couldn't read leaves the old one, with its old id.
local after = todo and readCopy(app)

local function lyricAt(f)
  for _, e in ipairs(after.flows[f.n].events) do
    if e.kind == "lyric" and e.streamId == f.e.streamId and e.line == 1 and e.text == f.new
      and values.positionText(e.position) == values.positionText(f.e.position) then
      return true
    end
  end
  return false
end

-- Puts a new text's placement back, and checks a change: f.why is set when Dorico left the old chord symbol, and
-- f.wrong when the change needs checking by hand.
local function settle(f)
  local e = f.e
  if not after then
    f.wrong = "the project couldn't be read back afterwards"
    return
  end
  if after.events[e.id] and e.kind == "chordSymbol" then
    f.why = "Dorico couldn't read the new one, so the old one is still there"
    return
  end
  local made = f.made and after.events[f.made]
  if made and f.placement and not e.system then edit.setProperty(app, made, PLACEMENT, f.placement) end
  if made and e.system then
    edit.select(app, made)
    app:doCommand("Edit.ChangeStaffTextToSystemText")
  end
  if after.events[e.id] then
    f.wrong = "the old one is still there"
  elseif (e.kind == "text" and not (made and made.words == f.new)) or (e.kind == "lyric" and not lyricAt(f)) then
    f.wrong = "the new one isn't there"
  end
end

for _, f in ipairs(found) do
  if not f.why then settle(f) end
end
if todo then app:doCommand("Edit.SelectNone") end

local replaced, left, toCheck = 0, 0, 0
for _, f in ipairs(found) do
  local line = where(f) .. "\t" .. shown(f.words)
  if f.why then
    print(line .. ": left as it is, " .. f.why)
    left = left + 1
  elseif f.wrong then
    print(line .. " -> " .. shown(f.new) .. ": check it, " .. f.wrong)
    toCheck = toCheck + 1
  else
    print(line .. " -> " .. shown(f.new))
    replaced = replaced + 1
  end
end
local summary = string.format("Replaced %d; left %d as they were", replaced, left)
print(summary .. (toCheck > 0 and string.format("; %d to check by hand.", toCheck) or "."))
