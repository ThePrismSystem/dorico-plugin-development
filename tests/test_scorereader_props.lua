-- An event's property entries and which applies where. A value can carry a context: a layout (-1 for every layout)
-- and a block instance (-1 for any). The reading fixture's notes have values set five different ways.
local props = require("scorereader.props")
local project = require("scorereader.project")
local tree = require("scorereader.tree")
local dtn = require("scorereader.dtn")
local build = require("dtn_build")

local here = debug.getinfo(1, "S").source:match("^@(.*[/\\])") or "./"

local READING
local function reading()
  READING = READING or project.readFile(here .. "../fixtures/6.2.30/reading.dorico").tree
  return READING
end

-- The note at pos with MIDI pitch that has an entry for property; event ids change when the fixture is rebuilt.
local function note(t, pos, pitch, property)
  for id in tree.each(t, "NoteEventDefinition") do
    if tree.value(t, tree.child(t, id, "position")) == pos and tree.value(t, tree.child(t, id, "pitch")) == pitch then
      for _, x in ipairs(props.entries(t, id)) do
        if x.property == property then return id end
      end
    end
  end
  error("no note at " .. pos .. " with pitch " .. pitch .. " and " .. property)
end

-- A tree holding one note with one kEventColour entry whose context has these {name, value} children.
local function coloured(context)
  return dtn.decode(build.tree({ "kScore", nil, { { "NoteEventDefinition", nil, {
    { "eventID", "7" },
    { "propertyTable", nil, { { "entries", nil, { { "entry", nil, {
      { "propertyType", "kEventColour" }, { "value", 'string: "#ffff0000"' }, { "context", nil, context },
    } } } } } },
  } } } }))
end

local function layoutChild(layout, frame, flag)
  return { "layoutIDWithFrameChainID", string.format("steamVariantList:list: {int: %d}, {int: %d}, {bool: %s}",
    layout, frame or -1, flag or "false") }
end

local function only(t)
  return props.entries(t, 1)[1]
end

local function refused(t, context, label)
  local ok, err = pcall(only, coloured(context))
  t:ok(not ok and tostring(err):find("^scorereader: a context the reader can't read"), label .. ": " .. tostring(err))
end

local function e(value, layout, instance, extra)
  local x = { property = "kNoteheadSetOverride", value = 'string: "' .. value .. '"', layout = layout, frameChain = -1,
    instance = instance }
  for k, v in pairs(extra or {}) do x[k] = v end
  return x
end

return {
  a_context_as_dorico_writes_it = function(t)
    local x = only(coloured({ { "propertyOffset", 'string: "0:0:1:0"' }, layoutChild(3),
      { "blockInstanceID", "-1" }, { "assignedStaveType", "kNormal" } }))
    t:eq(x.property, "kEventColour")
    t:eq(x.value, 'string: "#ffff0000"')
    t:eq(x.layout, 3)
    t:eq(x.frameChain, -1)
    t:eq(x.instance, -1)
    t:eq(x.offset, "0:0:1:0")
    t:eq(x.staveType, "kNormal")
  end,
  no_context_means_everywhere = function(t)
    local x = props.entries(reading(), note(reading(), "0", "67", "kNoteAccidentalVisibility_v3"))
    local found
    for _, y in ipairs(x) do if y.property == "kNoteAccidentalVisibility_v3" then found = y end end
    t:eq(found.layout, -1)
    t:eq(found.instance, -1)
  end,
  forms_the_reader_refuses = function(t)
    refused(t, { { "layoutIDWithFrameChainID", "layout three" }, { "blockInstanceID", "1" } }, "layout text")
    refused(t, { { "layoutIDWithFrameChainID", "steamVariantList:list: {int: 3}" }, { "blockInstanceID", "1" } },
      "short layout list")
    refused(t, { layoutChild(3), { "blockInstanceID", "x" } }, "instance")
    refused(t, { layoutChild(3), { "blockInstanceID", "-1" }, { "assignedStaveType", "kSmall" } }, "stave type")
    refused(t, { layoutChild(3), { "blockInstanceID", "-1" }, { "voiceIndex", "1" } }, "unknown child")
    refused(t, { { "blockInstanceID", "1010" } }, "no layout")
    refused(t, { layoutChild(3) }, "no instance")
  end,
  the_layout_counts_before_the_instance = function(t)
    t:eq(props.pick({ e("A", -1, -1), e("B", 0, -1) }, "kNoteheadSetOverride", 0, 1010), 'string: "B"')
    t:eq(props.pick({ e("A", -1, -1), e("B", 0, -1) }, "kNoteheadSetOverride", 3, 1010), 'string: "A"')
    t:eq(props.pick({ e("I", -1, 1010), e("L", 0, -1) }, "kNoteheadSetOverride", 0, 1010), 'string: "L"')
    t:eq(props.pick({ e("L", 0, -1), e("B", 0, 1010) }, "kNoteheadSetOverride", 0, 1010), 'string: "B"')
  end,
  a_value_only_for_another_instance = function(t)
    local v, elsewhere = props.pick({ e("C", -1, 1010) }, "kNoteheadSetOverride", 0, 1011)
    t:eq(v, nil)
    t:eq(elsewhere, true)
    t:eq(select(2, props.pick({ e("D", 5, 1010) }, "kNoteheadSetOverride", 0, 1011)), false, "another layout's")
  end,
  values_for_a_frame_chain_or_a_condensed_staff_are_left_out = function(t)
    t:eq(props.pick({ e("F", 0, -1, { frameChain = 2 }) }, "kNoteheadSetOverride", 0, 1010), nil)
    t:eq(props.pick({ e("K", -1, -1, { staveType = "kCondensed" }) }, "kNoteheadSetOverride", 0, 1010), nil)
  end,
  get_decodes_the_value = function(t)
    t:eq(props.get({ e("A", -1, -1) }, "kNoteheadSetOverride", 0, 1010), "A")
    t:eq(props.get({}, "kNoteheadSetOverride", 0, 1010), nil)
  end,
  a_part_only_colour_stays_in_its_part = function(t)
    -- the flute's E5, coloured with the flute part (layout 1) on screen
    local entries = props.entries(reading(), note(reading(), "2", "76", "kEventColour"))
    t:eq(props.get(entries, "kEventColour", 1, 1014), "#ff00a050", "in the part")
    t:eq(props.get(entries, "kEventColour", 0, 1014), nil, "not in the full score")
  end,
  a_notehead_set_by_command_belongs_to_its_instance = function(t)
    local entries = props.entries(reading(), note(reading(), "1", "74", "kNoteheadSetOverride"))
    t:eq(props.get(entries, "kNoteheadSetOverride", 0, 1014), "noteheadset.Xnoteheads")
    local v, elsewhere = props.get(entries, "kNoteheadSetOverride", 0, 1099)
    t:eq(v, nil)
    t:eq(elsewhere, true)
  end,
  brackets_set_from_the_menu_are_for_the_full_score = function(t)
    local entries = props.entries(reading(), note(reading(), "1", "69", "kNoteAccidentalVisibility_v3"))
    t:eq(props.get(entries, "kNoteAccidentalVisibility_v3", 0, 1026), "kSquareBrackets")
    t:eq(props.get(entries, "kNoteAccidentalVisibility_v3", 6, 1026), nil, "not in the violin part")
  end,
}
