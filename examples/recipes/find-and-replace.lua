-- Find words in staff text, system text, lyrics and chord symbols, and replace them where a script can.
-- What it does: reads a saved copy and asks what to find, whether to replace it, and where to look (a flow, a player,
-- a range of bars). Find lists every match (what it is, flow, bar and beat, player, the words) and selects the first.
-- Replace rebuilds each match with the new words and lists those it can't rebuild exactly, which it leaves as they
-- are.
-- Changes: in Replace, deletes each text, lyric or chord symbol it replaces and enters the new one in its place.
-- Find changes nothing.
-- Undo: Edit > Undo takes the whole run back in one step.
-- Builds on: 04-read-the-saved-copy.lua, 08-text-lyrics-chords-dynamics.lua, 09-bars-keys-and-times.lua,
-- 12-select-by-id.lua, 13-set-a-property-by-id.lua, 14-add-notes-rests-text.lua and 17-ask-and-report.lua (the form
-- helper). Open Script > Show Script Console to read what it prints.
--
-- Lua can't change a text's words, so a text is deleted and created again with createText in the same stream at the
-- same position, put below the staff again by id if it was there, and made a system text again through
-- Edit.ChangeStaffTextToSystemText if it was one. createText makes a plain text in the default paragraph style, so a
-- text with formatting inside it, in another paragraph style, with more than one paragraph or with settings of its own
-- (a colour or a nudge, say) is listed and left. A lyric is replaced only when it is a whole word on line 1 and the new
-- one is a single word, through the lyric commands on the note under it; a chord symbol through the chord-symbol
-- commands on a note at its position. Lyrics and chord symbols are entered in Write mode, so the script switches to it
-- when it has one to enter. Chord symbols are matched by the names the reader gives (plain major, minor and seventh
-- chords). The options are in the findtext helper below.

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

-- helper: reader
-- Puts the reader library on the module path: lib/ two folders up in this repository, or a lib folder beside the
-- script once both are copied into Script Plug-ins. Dorico keeps one Lua state, so the library's modules from an
-- earlier run are cleared first.
local function reader()
  local here = debug.getinfo(1, "S").source:match("^@(.*[/\\])") or ""
  local paths = here .. "../../lib/?.lua;" .. here .. "lib/?.lua"
  for name in pairs(package.loaded) do
    if name:match("^scorereader") then package.loaded[name] = nil end
  end
  if not package.path:find(paths, 1, true) then package.path = paths .. ";" .. package.path end
end
-- end helper: reader

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
    if type(numerator) == "number" then return numerator end
    local sum = 0
    for part in tostring(numerator):gmatch("%d+") do sum = sum + tonumber(part) end
    return sum
  end

  function bars.starts(divisions, endPos)
    local out, length = {}, nil
    local d1 = divisions[1]
    local base = (d1 and d1.pos == 0 and d1.numerator and d1.pickup) and -1 or 0
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
      if not length and pos < stop then add(pos, stop - pos) end
      if length and d.numerator and d.pickup and d.pickup > 0 and pos < stop then
        add(pos, math.min(d.pickup, stop - pos), length - d.pickup)
        pos = pos + d.pickup
      end
      while length and pos < stop do
        add(pos, math.min(length, stop - pos))
        pos = pos + length
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
    if not found then return 1, pos + 1 end
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

local TITLE = "Find and replace"
local ALL_FLOWS, ALL_PLAYERS = "All flows", "All players"
local DEFAULT_STYLE = "paragraph.defaulttext"
local PLACEMENT = "kTextEventAboveOrBelow"

local app, project = guard()
if not project then return end
reader()
local savedcopy = require("scorereader.dorico.savedcopy")
local commands = require("scorereader.dorico.commands")
local edit = require("scorereader.dorico.edit")
local score = require("scorereader.score")
local values = require("scorereader.values")

local ok, s = pcall(savedcopy.read, app)
if not ok then
  print("The reader couldn't read this project: " .. tostring(s))
  return
end

local playerLabels, flowLabels = { ALL_PLAYERS }, { ALL_FLOWS }
for _, player in ipairs(s.players) do playerLabels[#playerLabels + 1] = player.name end
for n, flow in ipairs(s.flows) do flowLabels[#flowLabels + 1] = n .. ": " .. flow.title end

-- Ask before changing anything, so that Cancel leaves nothing to undo.
local answers = form.ask(TITLE, {
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
  print("Cancelled: nothing changed.")
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

-- Where each flow's bars start, from its time signatures, as 09 does.
local function barsOf(flow)
  local divisions, endPos = {}, 0
  for _, e in ipairs(flow.events) do
    endPos = math.max(endPos, values.toNumber(e.position) + values.toNumber(e.duration))
    if e.kind == "timeSignature" then
      divisions[#divisions + 1] = { pos = values.toNumber(e.position), numerator = e.numerator,
        denominator = e.denominator, pickup = e.pickup and values.toNumber(e.pickup) }
    end
  end
  table.sort(divisions, function(a, b) return a.pos < b.pos end)
  return bars.starts(divisions, endPos)
end

local function wordsOf(e)
  if e.kind == "text" then return e.words end
  if e.kind == "lyric" then return e.text end
  return e.name
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
    if answers.flow == ALL_FLOWS or answers.flow == n .. ": " .. flow.title then
      local starts = barsOf(flow)
      for _, e in ipairs(flow.events) do
        local words = (e.kind == "text" or e.kind == "lyric" or e.kind == "chordSymbol") and wordsOf(e)
        local owner = words and score.ownerOf(s, e)
        local bar, beat = bars.at(starts, values.toNumber(e.position))
        if words and (answers.player == ALL_PLAYERS or (owner and owner.name == answers.player))
          and (not first or bar >= first) and (not last or bar <= last)
          and #findtext.matches(words, answers.query, answers) > 0 then
          found[#found + 1] = { e = e, flow = flow, n = n, bar = bar, beat = beat, words = words,
            who = owner and owner.name or "-" }
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

if answers.mode == "Find" then
  for _, f in ipairs(found) do print(where(f) .. "\t" .. shown(f.words)) end
  if #found == 0 then
    print("Found nothing.")
    return
  end
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

-- Why an item can't be rebuilt with its new words exactly, or nil when it can. For a text, also the placement to
-- restore: the value of every kTextEventAboveOrBelow it has, when they agree.
local function check(f, new)
  local e = f.e
  if e.kind == "text" then
    if e.formatted then return "it has formatting inside it" end
    if #e.paragraphs ~= 1 then return "it has more than one paragraph" end
    if e.paragraphs[1].style ~= DEFAULT_STYLE then return "it is in another paragraph style" end
    for _, x in ipairs(score.entries(s, e)) do
      if x.property ~= PLACEMENT or (f.placement and f.placement ~= x.value) then
        return "it has settings of its own (" .. x.property .. ")"
      end
      f.placement = x.value
    end
    f.placement = f.placement and values.typed(f.placement).value or (not e.above and "kBelow" or nil)
    if new == "" then return "the new words are empty" end
  elseif e.kind == "lyric" then
    if e.line ~= 1 or e.syllable ~= "single" or e.lineType ~= "verse" then
      return "only a whole-word lyric on line 1 can be replaced"
    end
    if not new:match("^[^%s%-]+$") then return "the new lyric isn't a single word" end
    f.note = noteIn(f.flow, e.streamId, e.position)
    if not f.note then return "there is no note under it" end
  else
    if not new:match("^%S+$") then return "the new chord symbol isn't one word" end
    f.note = noteIn(f.flow, nil, e.position)
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

local made, replaced, left, entering = {}, 0, 0, false
for _, f in ipairs(found) do
  if f.why then
    print(where(f) .. "\t" .. shown(f.words) .. ": left as it is, " .. f.why)
    left = left + 1
  else
    print(where(f) .. "\t" .. shown(f.words) .. " -> " .. shown(f.new))
    replaced = replaced + 1
    local e = f.e
    if e.kind == "text" then
      local stream = e.system and firstVoice[e.flowId] or streams[e.streamId]
      edit.delete(app, e)
      local t = stream:createText(DoCore.RhythmicLength(e.position.num, e.position.den), DoCore.RhythmicLength(0),
        f.new)
      made[#made + 1] = { id = t.id, placement = not e.system and f.placement or nil, system = e.system }
    else
      if not entering then
        app:doCommand("NoteInput.Exit")
        app:doCommand("Window.SwitchMode?WindowMode=kWriteMode")
        entering = true
      end
      edit.delete(app, e)
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

-- A new text has the ids the file gives only once it is saved, so placements and system texts go on after a read.
local after = #made > 0 and savedcopy.read(app)
for _, m in ipairs(made) do
  local e = after.events[m.id]
  if e and m.placement then edit.setProperty(app, e, PLACEMENT, m.placement) end
  if e and m.system then
    edit.select(app, e)
    app:doCommand("Edit.ChangeStaffTextToSystemText")
  end
end
app:doCommand("Edit.SelectNone")
print(string.format("Replaced %d; left %d as they were.", replaced, left))
