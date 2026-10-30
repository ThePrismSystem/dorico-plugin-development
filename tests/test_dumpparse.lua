-- fixtures/dumpparse.lua, with lines copied from real dumps.
local here = (arg and arg[0] or ""):match("^(.*[/\\])") or "./"
package.path = here .. "../fixtures/?.lua;" .. package.path
local dumpparse = require("dumpparse")

local function parse(lines)
  return dumpparse.parse(table.concat(lines, "\n") .. "\n").events
end

return {
  notes_rests_and_grace_notes = function(t)
    local ev = parse({
      "Start block id: 1061 position: 0",
      "0 (0) dur: 1: kNoteEvent (id:7932) at 0, duration 1  E5 (ends 1)",
      "0 (0) dur: 1: kRestEvent (id:216) at 0, duration 1  ",
      "8 (8): kGraceNoteEvent (id:200) at 8  secondary pos -1/2 (-0.5), notated duration: 1/2 (0.5), B6 ",
    })
    t:eq(ev[1].kind, "note")
    t:eq(ev[1].spelling, "E5")
    t:eq(ev[1].pos, 0)
    t:eq(ev[1].duration, 1)
    t:eq(ev[1].instance, 1061)
    t:eq(ev[2].kind, "rest")
    t:eq(ev[3].kind, "grace")
    t:eq(ev[3].spelling, "B6")
    t:eq(ev[3].pos, 8)
    t:eq(ev[3].duration, nil, "a grace note takes no time")
  end,
  fractions = function(t)
    local ev = parse({ "1.5 (3/2 (1.5)) dur: 1/2 (0.5): kNoteEvent (id:2884) at 3/2 (1.5), duration 1/2 (0.5)  Eb4 (ends 2)" })
    t:eq(ev[1].pos, 1.5)
    t:eq(ev[1].duration, 0.5)
    t:eq(ev[1].spelling, "Eb4")
  end,
  texts_and_other_kinds = function(t)
    local ev = parse({ "0 (0): kTextEvent (id:2740) at 0 : CANTOR", "0 (0): kLyricEvent (id:3) at 0  element ID = 0,  duration 0" })
    t:eq(ev[1].kind, "text")
    t:eq(ev[1].text, "CANTOR")
    t:eq(ev[2].kind, "other")
  end,
}
