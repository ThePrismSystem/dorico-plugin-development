-- Add the cautionary accidentals Dorico's own options can't: it looks back two bars, four bars or without limit, past
-- bars of rest and ties, and across an instrument's staves or between instruments.
-- What it does: asks how far to look back, which brackets to use and what to compare, reads a saved copy, and finds
-- every note that returns to its key signature, or to the bar's plain note, after an earlier note of the same letter
-- had another accidental. It prints one line per note (player, flow, bar and beat, the note, and the earlier note) and
-- shows that note's accidental in the brackets chosen, in every layout. Tick "Only take back" to take off every
-- accidental an earlier run added and add none.
-- Changes: the accidental visibility of the notes it lists, and of notes an earlier run marked.
-- Undo: Edit > Undo takes the whole run back in one step.
-- Builds on: 04-read-the-saved-copy.lua, 07-values-per-layout.lua, 09-bars-keys-and-times.lua,
-- 13-set-a-property-by-id.lua and 17-ask-and-report.lua (the form helper). Open Script > Show Script Console to read
-- what it prints.
--
-- Dorico itself decides the bar after an accidental and the rest of the bar it's in, on the same staff, by the flow's
-- notation options, so this script leaves those notes alone. The rules it follows are in the cautionary helper below.
-- It handles the common-practice accidental rule and skips a flow set to another. A note whose accidental you set
-- yourself, in any layout, is left as it is. The script's mark is an accidental visibility of round brackets, square
-- brackets or shown, stored for every layout, which the menu commands and the Properties panel never store; a run
-- takes off those it no longer needs, so the same setting made by a script of your own would go too. Pitches are
-- sounding pitches, so a transposing instrument's notes compare with other instruments' as they sound.

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

-- helper: cautionary
-- Which notes need a cautionary accidental that Dorico won't show. A note needs one when an earlier note of the same
-- letter, in any octave, had another accidental; no note its player reads (on its staff, or on the instrument's other
-- staves when those count) has had the note's own accidental since; the earlier note ends no more than lookBack bars
-- before the note's bar; and no key signature comes between them. An earlier note on the same staff in the bar before
-- or the same bar leaves the note to Dorico's own options. A note that already shows an accidental needs none.
--   cautionary.find(notes, keys, opts) -> {{id, from, reason}} in time order; from is the earlier note's id, reason is
--     "bars", "tie" (tied into the note's bar), "otherStaff" or "otherInstrument"
--   notes: {{id, spelling, pos, bar, endBar, staff, instrument, override}}: pos in quarter notes, bar where the note
--     starts and endBar where it ends, staff any value naming one staff, override true when the note has an
--     accidental setting of its own; grace notes left out
--   keys: {{pos, fifths}} in order, fifths nil for an atonal key; opts: lookBack (bars, nil for no limit),
--     restsCount (bars where the instrument plays nothing count), otherStaves, otherInstruments
local cautionary = {}
do
  local SHARPS, FLATS = "FCGDAEB", "BEADGCF"

  local function parse(spelling)
    local letter, accidentals, octave = spelling:match("^([A-G])([#bx]*)(%-?%d+)$")
    if not letter then error("not a spelling: " .. tostring(spelling), 3) end
    local alter = 0
    for c in accidentals:gmatch(".") do alter = alter + (c == "#" and 1 or c == "x" and 2 or -1) end
    return letter, alter, tonumber(octave)
  end

  -- The alteration a key signature of this many fifths gives a letter.
  local function keyAlter(letter, fifths)
    local order, sign = SHARPS, 1
    if fifths < 0 then order, sign, fifths = FLATS, -1, -fifths end
    local i = order:find(letter, 1, true)
    return sign * ((i <= fifths and 1 or 0) + (i <= fifths - 7 and 1 or 0))
  end

  local function fifthsAt(keys, pos)
    local fifths = 0
    for _, k in ipairs(keys) do
      if k.pos <= pos then fifths = k.fifths or 0 else break end
    end
    return fifths
  end

  local function keyChange(keys, from, to)
    for _, k in ipairs(keys) do
      if k.pos > from and k.pos <= to then return true end
    end
    return false
  end

  function cautionary.find(notes, keys, opts)
    local all, byLetter, playing = {}, {}, {}
    for i, n in ipairs(notes) do
      local letter, alter, octave = parse(n.spelling)
      all[i] = { n = n, letter = letter, alter = alter, octave = octave, order = i }
      local bars = playing[n.instrument] or {}
      playing[n.instrument] = bars
      for b = n.bar, n.endBar do bars[b] = true end
    end
    table.sort(all, function(a, b)
      if a.n.pos ~= b.n.pos then return a.n.pos < b.n.pos end
      return a.order < b.order
    end)
    for _, x in ipairs(all) do
      byLetter[x.letter] = byLetter[x.letter] or {}
      table.insert(byLetter[x.letter], x)
      x.index = #byLetter[x.letter]
    end

    -- Bars from the end of the earlier note y to note x's bar, leaving out bars where x's instrument plays nothing
    -- unless those count.
    local function distance(y, x)
      if opts.restsCount then return x.n.bar - y.n.endBar end
      local d = 0
      for b = y.n.endBar + 1, x.n.bar do
        if playing[x.n.instrument][b] then d = d + 1 end
      end
      return d
    end
    local function reads(x, y)
      return y.n.staff == x.n.staff or (opts.otherStaves and y.n.instrument == x.n.instrument)
    end
    local function counts(x, y)
      if y.n.instrument == x.n.instrument then return reads(x, y) end
      return opts.otherInstruments
    end

    local found = {}
    for _, x in ipairs(all) do
      local n, same = x.n, byLetter[x.letter]
      -- The alteration already in force for this note: an earlier note of the same letter and octave that starts in
      -- this bar on this staff, or else the key signature.
      local inForce = keyAlter(x.letter, fifthsAt(keys, n.pos))
      for j = x.index - 1, 1, -1 do
        local y = same[j]
        if y.n.bar < n.bar then break end
        if y.n.pos < n.pos and y.n.staff == n.staff and y.octave == x.octave then
          inForce = y.alter
          break
        end
      end
      if not n.override and x.alter == inForce then
        local from, dorico
        for j = x.index - 1, 1, -1 do
          local y = same[j]
          if y.n.pos < n.pos then
            if y.alter == x.alter and reads(x, y) then break end
            if y.alter ~= x.alter and counts(x, y) then
              if y.n.staff == n.staff and y.n.bar >= n.bar - 1 then
                dorico = true
                break
              end
              if not from and not keyChange(keys, y.n.pos, n.pos)
                and (not opts.lookBack or distance(y, x) <= opts.lookBack) then
                from = y
              end
            end
          end
        end
        if from and not dorico then
          local reason = "bars"
          if from.n.instrument ~= n.instrument then
            reason = "otherInstrument"
          elseif from.n.staff ~= n.staff then
            reason = "otherStaff"
          elseif from.n.endBar >= n.bar then
            reason = "tie"
          end
          found[#found + 1] = { id = n.id, from = from.n.id, reason = reason }
        end
      end
    end
    return found
  end
end
-- end helper: cautionary

-- helper: staffnotes
-- The notes of a flow the reader read, as the cautionary helper takes them, and the flow's key signatures. A note's
-- staff is its voice's staff, so a note crossed to the other staff by hand still counts on its voice's; its bars come
-- from the bars helper's starts. Each note keeps its event (event), and the caller sets override.
--   staffnotes.of(flow, values, bars, starts) -> notes, keys
local staffnotes = {}
do
  function staffnotes.of(flow, values, bars, starts)
    local notes, keys = {}, {}
    for _, e in ipairs(flow.events) do
      if e.kind == "keySignature" then keys[#keys + 1] = { pos = values.toNumber(e.position), fifths = e.fifths } end
    end
    table.sort(keys, function(a, b) return a.pos < b.pos end)
    for _, stream in ipairs(flow.streams) do
      if stream.type == "voice" then
        for _, e in ipairs(stream.events) do
          if e.kind == "note" then
            local pos = values.toNumber(e.position)
            local last = math.max(pos, pos + values.toNumber(e.duration) - 1 / 1024)
            notes[#notes + 1] = { id = e.id, spelling = e.spelling, pos = pos, bar = (bars.at(starts, pos)),
              endBar = (bars.at(starts, last)), staff = stream.instrumentId .. ":" .. tostring(stream.staff),
              instrument = stream.instrumentId, event = e }
          end
        end
      end
    end
    return notes, keys
  end
end
-- end helper: staffnotes

local TITLE = "Cautionary accidentals"
local PROPERTY = "kNoteAccidentalVisibility_v3"
local LOOK_BACK = { ["2 bars"] = 2, ["4 bars"] = 4 }
local BRACKETS = { ["Round brackets"] = "kRoundBrackets", ["Square brackets"] = "kSquareBrackets",
  ["No brackets"] = "kShow" }
local MARKS = { kRoundBrackets = true, kSquareBrackets = true, kShow = true }
local FIELDS = {
  { key = "lookBack", label = "Look back", kind = "choice", default = "4 bars",
    choices = { "2 bars", "4 bars", "No limit" } },
  { key = "brackets", label = "Brackets", kind = "choice", default = "Round brackets",
    choices = { "Round brackets", "Square brackets", "No brackets" } },
  { key = "restsCount", label = "Count bars of rest", kind = "check", default = true },
  { key = "otherStaves", label = "The instrument's other staves", kind = "check", default = true },
  { key = "otherInstruments", label = "Other instruments", kind = "check", default = false },
  { key = "remove", label = "Only take back", kind = "check", default = false },
}

local app, project = guard()
if not project then return end
-- Ask before changing anything, so that Cancel leaves nothing to undo.
local answers = form.ask(TITLE, FIELDS)
if not answers then
  print("Cancelled: nothing changed.")
  return
end
reader()
local savedcopy = require("scorereader.dorico.savedcopy")
local edit = require("scorereader.dorico.edit")
local score = require("scorereader.score")
local values = require("scorereader.values")

local ok, s = pcall(savedcopy.read, app)
if not ok then
  print("The reader couldn't read this project: " .. tostring(s))
  return
end

-- This script's mark: one of its values with no layout and no block instance. Any other accidental setting on a
-- note is the user's.
local function isMark(x)
  return x.property == PROPERTY and x.layout == -1 and x.instance == -1 and MARKS[values.typed(x.value).value] == true
end
local marked, own = {}, {}
for _, flow in ipairs(s.flows) do
  for _, e in ipairs(flow.events) do
    if e.kind == "note" then
      for _, x in ipairs(score.entries(s, e)) do
        if isMark(x) then
          marked[e.id] = values.typed(x.value).value
        elseif x.property == PROPERTY then
          own[e.id] = true
        end
      end
    end
  end
end
if answers.remove then
  local n = 0
  for id in pairs(marked) do
    edit.removeProperty(app, s.events[id], PROPERTY)
    n = n + 1
  end
  print(string.format("Took back %d cautionary accidentals.", n))
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

local playerOf = {}
for _, player in ipairs(s.players) do
  for _, instrument in ipairs(player.instruments) do playerOf[instrument.id] = player.name end
end

local opts = { lookBack = LOOK_BACK[answers.lookBack], restsCount = answers.restsCount,
  otherStaves = answers.otherStaves, otherInstruments = answers.otherInstruments }
local value = BRACKETS[answers.brackets]
local wanted, handled, added, kept, takenBack = {}, {}, 0, 0, 0
for n, flow in ipairs(s.flows) do
  local rule = flow.options.accidentals and flow.options.accidentals.durationBehaviour
  if rule ~= "kCommonPractice" then
    print(string.format("Flow %d uses the accidental rule %s, which this script doesn't handle: skipped.", n,
      tostring(rule)))
  else
    local starts = barsOf(flow)
    local notes, keys = staffnotes.of(flow, values, bars, starts)
    local byId = {}
    for _, x in ipairs(notes) do
      x.override = own[x.id] == true
      byId[x.id] = x
      handled[x.id] = true
    end
    for _, f in ipairs(cautionary.find(notes, keys, opts)) do
      local x, from = byId[f.id], byId[f.from]
      local bar, beat = bars.at(starts, x.pos)
      local why = from.spelling .. " in bar " .. from.bar
      if f.reason == "tie" then
        why = from.spelling .. " tied into the bar"
      elseif f.reason == "otherStaff" then
        why = from.spelling .. " on the other staff in bar " .. from.bar
      elseif f.reason == "otherInstrument" then
        why = playerOf[from.instrument] .. "'s " .. from.spelling .. " in bar " .. from.bar
      end
      print(string.format("%s\tflow %d\tbar %d, beat %g\t%s, after %s", playerOf[x.instrument], n, bar, beat,
        x.spelling, why))
      wanted[f.id] = true
      if marked[f.id] == value then
        kept = kept + 1
      else
        edit.setProperty(app, x.event, PROPERTY, value)
        added = added + 1
      end
    end
  end
end
for id in pairs(marked) do
  if handled[id] and not wanted[id] then
    edit.removeProperty(app, s.events[id], PROPERTY)
    takenBack = takenBack + 1
  end
end
print(string.format("Added %d cautionary accidentals, kept %d from an earlier run, took back %d.", added, kept,
  takenBack))
