-- Names Lua can't read directly, from Dorico's text export: the project's title and file path, flow titles and
-- instrument names.
-- What it does: prints "project: <title>", "path: <file>", a "flow <n>: <title>" line per flow and an
-- "instrument <n>: <name>" line per instrument, in player order.
-- Changes: nothing that stays. It puts a marker text in one voice of each instrument, runs File > Export > Text
-- into the temporary folder, and deletes the markers and the exported file again.
-- Undo: nothing to undo. Texts made and deleted through the stream object never enter the undo history.
-- Builds on: 02-walk-the-score.lua. Open Script > Show Script Console to read what it prints.
--
-- Lua gives a flow no title, an instrument no name and the project no path. The text export lists every text in the
-- project, one row each, with columns Path, ID, FlowNumber, FlowName, Instrument, Page, Bar, Type, Text and Hidden,
-- so a script can learn those things by reading it back. Every row's Path is the project's file, or empty until the
-- project has been saved. "Flow Info (Title)" rows give each flow's title. An instrument shows up only in the rows of
-- texts on its staff, so the script makes one: a marker text it can find again by what it says.
--
-- An instrument's name in the export has none of the transposition Dorico adds to a player's name: the player
-- "Trumpet Zoë (B{@flat@})" plays the instrument "Trumpet Zoë".

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
-- escape, so a value's own backslashes and ampersands each get one in front; "=" and any other character pass as
-- they are. A nil value is refused, since tostring would send Dorico the word "nil".
--   commands.value(v) -> v escaped
--   commands.build(name, params) -> the command, params a list of {key, value} pairs
local commands = {}
do
  function commands.value(v)
    if v == nil then error("a command parameter has no value", 2) end
    return (tostring(v):gsub("\\", "\\\\"):gsub("&", "\\&"))
  end

  function commands.build(name, params)
    local parts = {}
    for i, kv in ipairs(params or {}) do parts[i] = kv[1] .. "=" .. commands.value(kv[2]) end
    if #parts == 0 then return name end
    return name .. "?" .. table.concat(parts, "&")
  end
end
-- end helper: commands

-- helper: export
-- File > Export > Text from a script: Dorico writes <name>.csv beside the <name>.txt it is given, without asking
-- anything. Fields can hold quoted commas, doubled quotes and newlines, so the CSV is read with a quote-aware reader,
-- never split line by line. A column the export leaves out reads as "".
--   export.records(app, folder, name) -> the rows, as tables keyed by column name (the file is deleted afterwards)
--   export.parse(csv) -> the same, from CSV text
--   export.folder() -> the temporary folder, ending in a slash
-- Needs the commands helper above it.
local export = {}
do
  local COLUMNS = { "Path", "ID", "FlowNumber", "FlowName", "Instrument", "Page", "Bar", "Type", "Text", "Hidden" }

  local function rows(csv)
    if csv:sub(1, 3) == "\239\187\191" then csv = csv:sub(4) end -- a UTF-8 byte-order mark
    local out, row, field = {}, {}, {}
    local i, n, quoted, lineStart = 1, #csv, false, 1
    while i <= n do
      local c = csv:sub(i, i)
      if not quoted and (c == "\n" or c == "\r") and i == lineStart then
        -- a blank line is no row
        if c == "\r" and csv:sub(i + 1, i + 1) == "\n" then i = i + 1 end
        lineStart = i + 1
      elseif quoted then
        if c == '"' then
          if csv:sub(i + 1, i + 1) == '"' then field[#field + 1] = '"'; i = i + 1 else quoted = false end
        else
          field[#field + 1] = c
        end
      elseif c == '"' then
        quoted = true
      elseif c == "," then
        row[#row + 1] = table.concat(field)
        field = {}
      elseif c == "\n" or c == "\r" then
        if c == "\r" and csv:sub(i + 1, i + 1) == "\n" then i = i + 1 end
        row[#row + 1] = table.concat(field)
        out[#out + 1] = row
        row, field, lineStart = {}, {}, i + 1
      else
        field[#field + 1] = c
      end
      i = i + 1
    end
    if #field > 0 or #row > 0 then
      row[#row + 1] = table.concat(field)
      out[#out + 1] = row
    end
    return out
  end

  function export.parse(csv)
    local all = rows(csv)
    local header = all[1] or {}
    local records = {}
    for r = 2, #all do
      local rec = {}
      for _, name in ipairs(COLUMNS) do rec[name] = "" end
      for col, name in ipairs(header) do rec[name] = all[r][col] or "" end
      records[#records + 1] = rec
    end
    return records
  end

  function export.folder()
    local dir = os.getenv("TEMP") or os.getenv("TMPDIR") or os.getenv("TMP")
    if not dir then error("there is no TEMP or TMPDIR folder to export into") end
    if not dir:match("[/\\]$") then dir = dir .. "/" end
    return dir
  end

  function export.records(app, folder, name)
    local base = folder .. name
    os.remove(base .. ".csv")
    app:doCommand(commands.build("File.Export.Text", { { "File", base .. ".txt" }, { "Show", "false" } }))
    local f = io.open(base .. ".csv", "rb")
    if not f then error("File.Export.Text wrote no " .. base .. ".csv") end
    local csv = f:read("*a")
    f:close()
    os.remove(base .. ".csv")
    return export.parse(csv)
  end
end
-- end helper: export

local app, score = guard()
if not score then return end

-- Instruments in player order, by id.
local order = {}
for _, player in ipairs(score.players) do
  for _, instrument in ipairs(player.instruments) do order[#order + 1] = instrument.id end
end

-- A marker at the start of the first voice of each instrument, in whichever flow has it first.
local MARKER = "names-from-the-text-export "
local markers, marked = {}, {}
for _, flow in ipairs(score.flows) do
  for i, stream in ipairs(flow.voiceStreams) do
    local id = flow.instruments[i].id
    if not marked[id] then
      marked[id] = true
      local event = stream:createText(DoCore.RhythmicLength(0), DoCore.RhythmicLength(1), MARKER .. id)
      markers[#markers + 1] = { stream = stream, event = event }
    end
  end
end

-- The markers go whether or not the export works.
local ok, records = pcall(export.records, app, export.folder(), "names-from-the-text-export")
for _, m in ipairs(markers) do m.stream:delete(m.event) end
if not ok then error(records, 0) end

local path, title, flowTitles, instrumentNames = "", "", {}, {}
for _, rec in ipairs(records) do
  if path == "" then path = rec.Path end
  if rec.Type == "Project Info (Title)" then title = rec.Text end
  -- Some projects export these rows with no FlowNumber (Steinberg's Smith example does). Then only the set of
  -- titles is known, not which flow has which.
  if rec.Type == "Flow Info (Title)" and tonumber(rec.FlowNumber) then
    flowTitles[tonumber(rec.FlowNumber)] = rec.Text
  end
  if rec.Text:sub(1, #MARKER) == MARKER then
    instrumentNames[tonumber(rec.Text:sub(#MARKER + 1))] = rec.Instrument
  end
end

print("project: " .. title)
print("path: " .. (path ~= "" and path or "(not saved yet)"))
for n = 1, #score.flows do print("flow " .. n .. ": " .. (flowTitles[n] or "?")) end
for n, id in ipairs(order) do print("instrument " .. n .. ": " .. (instrumentNames[id] or "(in no flow)")) end
