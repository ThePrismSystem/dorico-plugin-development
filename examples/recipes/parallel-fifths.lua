-- Find consecutive fifths and octaves between every pair of parts, and colour the notes involved. It flags; it never
-- changes a pitch or rhythm.
-- What it does: asks which checks to run, reads a saved copy, and compares every pair of parts in every flow: each
-- voice is a part, and so is each note of a chord, counted from the top, a held note included. It prints one line per
-- finding (what it is, the flow, bar and beat, and the two parts) and colours the notes involved with its own colour,
-- #ffd81b60, in every layout. A note that already has a colour of its own keeps it and is only listed. Tick "Only
-- remove marks" to take this script's colour off every note and change nothing else.
-- Changes: the colour of the notes in a finding, and of notes an earlier run coloured.
-- Undo: Edit > Undo takes the whole run back in one step.
-- Builds on: 04-read-the-saved-copy.lua, 09-bars-keys-and-times.lua, 13-set-a-property-by-id.lua and
-- 17-ask-and-report.lua (the form helper). Open Script > Show Script Console to read what it prints.
--
-- It checks common-practice voice leading, and plenty of music breaks those rules on purpose. The rules it follows
-- are in the parallels helper below. Every run first takes its colour off any note that has exactly #ffd81b60 with no
-- layout of its own, so a run never piles marks on an earlier one; a colour you set to that exact value, for every
-- layout, would go too. A note that also has a colour of its own keeps the mark, and the run says how many did, since
-- no run has shown that taking the mark off would leave the other colour. Pitches are sounding pitches.

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

-- helper: readCopy
-- Reads a saved copy of the open project with the reader library, or prints why it couldn't and gives nil. The
-- library is lib/ two folders up in this repository, or a lib folder beside the script once both are copied into
-- Script Plug-ins. Dorico keeps one Lua state, so the library's modules from an earlier run are cleared, and its
-- folders are moved to the front of the module path, where no other copy of the library can come before them.
local function readCopy(app)
  local here = debug.getinfo(1, "S").source:match("^@(.*[/\\])") or ""
  local paths = here .. "../../lib/?.lua;" .. here .. "lib/?.lua;"
  for name in pairs(package.loaded) do
    if name:match("^scorereader") then package.loaded[name] = nil end
  end
  local at = package.path:find(paths, 1, true)
  if at then package.path = package.path:sub(1, at - 1) .. package.path:sub(at + #paths) end
  package.path = paths .. package.path
  local ok, s = pcall(function() return require("scorereader.dorico.savedcopy").read(app) end)
  if ok then return s end
  print("The reader couldn't read this project: " .. tostring(s))
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

-- helper: parallels
-- Consecutive fifths, octaves and unisons between every pair of parts.
--   parallels.find(parts, opts) -> {{kind, a, b, pos, notes = {a1, b1, a2, b2}}}, in time order; kind is "fifths",
--     "octaves", "unisons", "hidden fifths", "hidden octaves", "contrary fifths" or "contrary octaves"
--   parts: {{name, notes = {{id, pos, duration, pitch, grace}}}}, one line of notes each, with sounding MIDI pitches
--     and positions and durations in quarter notes
--   opts: hidden, contrary, doublings and outerOnly are off unless set; restBreaks and unisons are on unless false
-- Two moments are compared when both parts sound at each and both move to a new pitch: a held or repeated note is no
-- motion. Intervals are compared without their octaves, so a twelfth is a fifth, and a pair stays the same pair when
-- the parts cross. A rest in either part breaks the chain unless restBreaks is false. Grace notes are left out. Three
-- or more consecutive octaves or unisons in a row, four notes in each part moving together, are a doubling and are
-- left out unless doublings is set. A repeated or held note that keeps the parts in octaves doesn't end that run, so a
-- doubling in another rhythm counts too. Hidden fifths and octaves (similar motion into one, with a leap in the upper
-- part) count only between the outer parts sounding at both moments. outerOnly keeps only findings between those.
local parallels = {}
do
  -- The note of a line sounding at t, for times that only increase.
  local function cursor(notes)
    local i = 1
    return function(t)
      while notes[i] and notes[i].pos + notes[i].duration <= t do i = i + 1 end
      local n = notes[i]
      if n and n.pos <= t then return n end
    end
  end

  local function timesOf(parts)
    local seen, out = {}, {}
    for _, p in ipairs(parts) do
      for _, n in ipairs(p.notes) do
        for _, t in ipairs({ n.pos, n.pos + n.duration }) do
          if not seen[t] then seen[t], out[#out + 1] = true, t end
        end
      end
    end
    table.sort(out)
    return out
  end

  -- The kind of finding a move from moment p to moment v makes, or nil; the second value is true for a parallel
  -- octave or unison, which the doubling rule counts.
  local function compare(p, v, outer, opts)
    local ma, mb = v.a.pitch - p.a.pitch, v.b.pitch - p.b.pitch
    if ma == 0 or mb == 0 then return nil end
    local i1, i2 = p.a.pitch - p.b.pitch, v.a.pitch - v.b.pitch
    local c1, c2 = math.abs(i1) % 12, math.abs(i2) % 12
    if c2 ~= 7 and c2 ~= 0 then return nil end
    local name = c2 == 7 and "fifths" or "octaves"
    local similar = (ma > 0) == (mb > 0)
    if c1 == c2 then
      if not similar then return opts.contrary and ("contrary " .. name) or nil end
      if c2 == 0 and i1 == 0 and i2 == 0 then return "unisons", true end
      return name, c2 == 0
    end
    if similar and opts.hidden and outer then
      local upper = v.a.pitch >= v.b.pitch and ma or mb
      if math.abs(upper) > 2 then return "hidden " .. name end
    end
  end

  local function pairFindings(A, B, ends, opts, out)
    local restBreaks = opts.restBreaks ~= false
    local ca, cb = cursor(A.notes), cursor(B.notes)
    local run, prev, gap = {}, nil, false
    local function keep(f)
      if f.kind ~= "unisons" or opts.unisons ~= false then out[#out + 1] = f end
    end
    local function flush()
      if #run < 3 or opts.doublings then
        for _, f in ipairs(run) do keep(f) end
      end
      run = {}
    end
    local function isOuter(m)
      local e = ends[m.t]
      return math.max(m.a.pitch, m.b.pitch) == e.top and math.min(m.a.pitch, m.b.pitch) == e.bottom
    end
    for _, t in ipairs(timesOf({ A, B })) do
      local a, b = ca(t), cb(t)
      if not (a and b) then
        gap = true
        flush()
      elseif not prev or a ~= prev.a or b ~= prev.b then
        local v = { a = a, b = b, t = t }
        if prev and not (gap and restBreaks) then
          local outer = isOuter(prev) and isOuter(v)
          local kind, octaveLike = compare(prev, v, outer, opts)
          local f = kind and (outer or not opts.outerOnly)
            and { kind = kind, a = A.name, b = B.name, pos = t, notes = { prev.a, prev.b, a, b } }
          -- A repeated or held note that keeps the two parts in octaves carries a doubling on.
          local stillDoubled = not kind and (prev.a.pitch - prev.b.pitch) % 12 == 0 and (a.pitch - b.pitch) % 12 == 0
          if f and octaveLike then
            run[#run + 1] = f
          elseif not stillDoubled then
            flush()
            if f then keep(f) end
          end
        end
        prev, gap = v, false
      end
    end
    flush()
  end

  function parallels.find(parts, opts)
    opts = opts or {}
    local lines = {}
    for i, p in ipairs(parts) do
      local notes = {}
      for _, n in ipairs(p.notes) do
        if not n.grace and n.duration > 0 then notes[#notes + 1] = n end
      end
      table.sort(notes, function(x, y) return x.pos < y.pos end)
      lines[i] = { name = p.name, notes = notes }
    end
    -- The highest and lowest pitch sounding at each moment, for the outer-part rules.
    local ends, cursors = {}, {}
    for i, line in ipairs(lines) do cursors[i] = cursor(line.notes) end
    for _, t in ipairs(timesOf(lines)) do
      local top, bottom
      for i = 1, #lines do
        local n = cursors[i](t)
        if n then
          top = math.max(top or n.pitch, n.pitch)
          bottom = math.min(bottom or n.pitch, n.pitch)
        end
      end
      ends[t] = { top = top, bottom = bottom }
    end
    local out = {}
    for i = 1, #lines do
      for j = i + 1, #lines do pairFindings(lines[i], lines[j], ends, opts, out) end
    end
    for i, f in ipairs(out) do f.order = i end
    table.sort(out, function(x, y)
      if x.pos ~= y.pos then return x.pos < y.pos end
      return x.order < y.order
    end)
    return out
  end
end
-- end helper: parallels

-- helper: lines
-- One part per voice of a flow the reader read, and one per note of a chord, counted from the top, each named after
-- its player: "Violin", "Piano voice 2", "Piano, note 2 from the top". At each moment a note starts in a voice, every
-- note sounding there, struck or held, is counted from the top up to the next such moment, so a note held in a chord
-- stays in its part while the notes under it move.
--   lines.of(s, flow, values) -> parts as the parallels helper takes them
local lines = {}
do
  function lines.of(s, flow, values)
    local parts, voices = {}, {}
    for _, stream in ipairs(flow.streams) do
      if stream.type == "voice" then
        local player
        for _, p in ipairs(s.players) do
          if p.id == stream.playerId then player = p end
        end
        local name = player and player.name or ("stream " .. stream.id)
        voices[name] = (voices[name] or 0) + 1
        local notes, onsets, seen = {}, {}, {}
        for _, e in ipairs(stream.events) do
          if e.kind == "note" then
            local pos = values.toNumber(e.position)
            notes[#notes + 1] = { e = e, pos = pos, stop = pos + values.toNumber(e.duration) }
            if not seen[pos] then seen[pos], onsets[#onsets + 1] = true, pos end
          end
        end
        table.sort(notes, function(x, y) return x.pos < y.pos end)
        table.sort(onsets)
        local ranks, sounding, upto = {}, {}, 1
        for i, t in ipairs(onsets) do
          local still = {}
          for _, n in ipairs(sounding) do
            if n.stop > t then still[#still + 1] = n end
          end
          sounding = still
          while notes[upto] and notes[upto].pos <= t do
            if notes[upto].stop > t then sounding[#sounding + 1] = notes[upto] end
            upto = upto + 1
          end
          table.sort(sounding, function(x, y) return x.e.pitch > y.e.pitch end)
          for rank, n in ipairs(sounding) do
            ranks[rank] = ranks[rank] or {}
            local stop = math.min(n.stop, onsets[i + 1] or n.stop)
            table.insert(ranks[rank], { id = n.e.id, pos = t, duration = stop - t, pitch = n.e.pitch })
          end
        end
        for rank, notes in ipairs(ranks) do
          local label = name .. (voices[name] > 1 and (" voice " .. voices[name]) or "")
          if #ranks > 1 then label = label .. ", note " .. rank .. " from the top" end
          parts[#parts + 1] = { name = label, notes = notes }
        end
      end
    end
    return parts
  end
end
-- end helper: lines

local MARK = "#ffd81b60"
local TITLE = "Parallel fifths and octaves"
local FIELDS = {
  { key = "hidden", label = "Hidden fifths and octaves", kind = "check", default = false },
  { key = "contrary", label = "Contrary fifths and octaves", kind = "check", default = false },
  { key = "doublings", label = "Count doublings", kind = "check", default = false },
  { key = "outerOnly", label = "Outer parts only", kind = "check", default = false },
  { key = "restBreaks", label = "A rest breaks a run", kind = "check", default = true },
  { key = "unisons", label = "Count unisons", kind = "check", default = true },
  { key = "clear", label = "Only remove marks", kind = "check", default = false },
}

local app, project = guard()
if not project then return end
-- Ask before changing anything, so that Cancel leaves nothing to undo.
local answers, noBox = form.ask(TITLE, FIELDS)
if not answers then
  print(noBox and "The box didn't work: " .. noBox or "Cancelled: nothing changed.")
  return
end
local s = readCopy(app)
if not s then return end
local edit = require("scorereader.dorico.edit")
local score = require("scorereader.score")
local values = require("scorereader.values")

-- Take an earlier run's marks off, and note which notes have a colour of their own. No run has shown whether taking
-- the mark off leaves a colour set for one layout alone, so a note with both keeps the mark.
local cleared, left, own = 0, 0, {}
for _, flow in ipairs(s.flows) do
  for _, e in ipairs(flow.events) do
    if e.kind == "note" or e.kind == "grace" then
      local mark, theirs = false, false
      for _, x in ipairs(score.entries(s, e)) do
        if x.property == "kEventColour" then
          if values.typed(x.value).value == MARK and x.layout == -1 and x.instance == -1 then
            mark = true
          else
            theirs = true
          end
        end
      end
      own[e.id] = theirs or nil
      if mark and theirs then
        left = left + 1
      elseif mark then
        edit.removeProperty(app, e, "kEventColour")
        cleared = cleared + 1
      end
    end
  end
end
local function sayLeft()
  if left == 0 then return end
  print(string.format("Left it on %d %s also %s a colour of its own, since taking it off could take that colour too.",
    left, left == 1 and "note that" or "notes that", left == 1 and "has" or "have"))
end
if answers.clear then
  print(string.format("Took this script's colour off %d notes.", cleared))
  sayLeft()
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

local toMark, count = {}, 0
for n, flow in ipairs(s.flows) do
  local starts = barsOf(flow)
  for _, f in ipairs(parallels.find(lines.of(s, flow, values), answers)) do
    count = count + 1
    local bar, beat = bars.at(starts, f.pos)
    print(string.format("%s\tflow %d\tbar %d, beat %g\t%s and %s", f.kind, n, bar, beat, f.a, f.b))
    for _, note in ipairs(f.notes) do toMark[note.id] = true end
  end
end

local marked, kept = 0, 0
for id in pairs(toMark) do
  if own[id] then
    kept = kept + 1
  else
    edit.setProperty(app, s.events[id], "kEventColour", MARK)
    marked = marked + 1
  end
end
print(string.format("%d found; %d notes coloured, %d kept their own colour; %d old marks taken off.", count, marked,
  kept, cleared))
sayLeft()
