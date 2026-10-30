-- Change layout and notation options: hide the full score's flow headings, and end the first flow with a double
-- barline.
-- What it does: sets the full score's flowHeadingBehaviour to kNoFlowHeadings and the first flow's
-- barlineOptions.finalBarlineType to kDouble, prints each change, then prints the text frames that the export no
-- longer lists, which is how a script can see that the headings went.
-- Changes: those two options. Change the values below to set others.
-- Undo: Edit > Undo puts both options back in one step.
-- Builds on: 10-commands.lua. Its export helper reads the text export (docs/guide.md, section 4). Open
-- Script > Show Script Console to read what it prints.
--
-- Layout Options and Notation Options are set by command, in the form Dorico itself uses (it logs it when the
-- Remote Control API sets an option):
--   Project.Layout.SetOptions?Dictionary=<list>&OpenScoreID=<score.openScoreID>&LayoutIDArray=<layout id>
--   Project.Flow.SetNotationOptions?Dictionary=<list>&OpenScoreID=<score.openScoreID>&FlowIDArray=<flow id>
-- The list alternates an option's path and its value, each written {string: "..."}. Option paths and values are the
-- names the Remote Control API's getoptions reports.
--
-- Lua can't read any option back, so overwriting one loses the old value unless the script can work it out another
-- way. The text export is one way: a flow heading is a text frame, so its row is there only while headings show.

local LAYOUT_OPTION = { "flowHeadingBehaviour", "kNoFlowHeadings" }
local FLOW_OPTION = { "barlineOptions.finalBarlineType", "kDouble" }

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

-- helper: export
-- File > Export > Text from a script: Dorico writes <name>.csv beside the <name>.txt it is given, without asking
-- anything. Fields can hold quoted commas, doubled quotes and newlines, so a row can run over several lines; the
-- reader below keeps track of quotes to find where each field and row ends. A column the export leaves out reads as "".
--   export.records(app, folder, name) -> the rows, as tables keyed by column name (the file is deleted afterwards);
--     raises an error for a folder that isn't all ASCII, an old CSV it can't delete, or no CSV
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
    -- Dorico takes the path in UTF-8 and io.open in the code page, and the two agree only on ASCII, so another folder
    -- would give a missing CSV with no reason.
    if folder:find("[\128-\255]") then
      error("the folder for the export, " .. folder .. ", has characters outside ASCII, which Dorico and Lua spell"
        .. " differently")
    end
    local base = folder .. name
    -- doCommand reports nothing, so a CSV left from before would be read as this export's if Dorico wrote none.
    -- os.remove's third result is the error number, and 2 means there was no file to delete.
    local gone, _, code = os.remove(base .. ".csv")
    if not gone and code ~= 2 then error("couldn't delete the last export, " .. base .. ".csv") end
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

-- The list as Dorico reads it, before the commands helper escapes it: commas between the items, which the helper
-- turns into "\," as Dorico logs them. The helper escapes a comma or a backslash inside a path or value the same way,
-- which is what Dorico wants there too. A quote inside a value needs "\"", which this can't make, since the helper
-- would escape that backslash as well; the paths and values here have no quotes.
local function dictionary(path, value)
  return 'list: {string: "' .. path .. '"}, {string: "' .. value .. '"}'
end

-- The full score is the layout that holds every player; Dorico makes it first, so it has the lowest id. Layouts have
-- players but no name Lua can read, and players have no ==, so they're matched by their first instrument's id. A
-- player with no instruments can't be matched, so it's left out.
local function fullScore()
  local best
  for _, layout in ipairs(score.layouts) do
    local has = {}
    for _, player in ipairs(layout.players) do
      if player.instruments[1] then has[player.instruments[1].id] = true end
    end
    local all = true
    for _, player in ipairs(score.players) do
      if player.instruments[1] and not has[player.instruments[1].id] then all = false end
    end
    if all and (not best or layout.id < best.id) then best = layout end
  end
  return best
end

-- The text frames the export lists, as "page <n>: <text>".
local function textFrames()
  local frames = {}
  for _, rec in ipairs(export.records(app, export.folder(), "layout-and-notation-options")) do
    if rec.Type == "Text Frame" then frames[#frames + 1] = "page " .. rec.Page .. ": " .. rec.Text end
  end
  return frames
end

local layout = fullScore()
if not layout then error("no layout holds every player") end
local framesBefore = textFrames()

app:doCommand(commands.build("Project.Layout.SetOptions", { { "Dictionary", dictionary(LAYOUT_OPTION[1],
  LAYOUT_OPTION[2]) }, { "OpenScoreID", score.openScoreID }, { "LayoutIDArray", layout.id } }))
print(string.format("full score (layout %d): %s = %s", layout.id, LAYOUT_OPTION[1], LAYOUT_OPTION[2]))

local flow = score.flows[1]
app:doCommand(commands.build("Project.Flow.SetNotationOptions", { { "Dictionary", dictionary(FLOW_OPTION[1],
  FLOW_OPTION[2]) }, { "OpenScoreID", score.openScoreID }, { "FlowIDArray", flow.id } }))
print(string.format("flow 1 (id %d): %s = %s", flow.id, FLOW_OPTION[1], FLOW_OPTION[2]))

local after = {}
for _, frame in ipairs(textFrames()) do after[frame] = true end
for _, frame in ipairs(framesBefore) do
  if not after[frame] then print("text frame gone: " .. frame) end
end
