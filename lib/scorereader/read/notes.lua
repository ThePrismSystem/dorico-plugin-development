-- Notes, grace notes and tuplets.
local values = require("scorereader.values")
local props = require("scorereader.props")

local notes = {}

local SEMITONES = { C = 0, D = 2, E = 4, F = 5, G = 7, A = 9, B = 11 }

-- "F#5" from the letter Dorico stores (kNoteSpelling holds only "F") and the sounding MIDI pitch: the octave is the
-- one whose natural is nearest the pitch, and the difference is the accidental. The same form as stream:dump(), which
-- writes a double sharp as "x" ("Dx4") and a double flat as "bb".
local ACCIDENTALS = { [-2] = "bb", [-1] = "b", [0] = "", [1] = "#", [2] = "x" }

function notes.spelling(letter, pitch)
  local best
  for octave = -1, 9 do
    local alter = pitch - (12 * (octave + 1) + SEMITONES[letter])
    if math.abs(alter) <= 2 and (not best or math.abs(alter) < math.abs(best.alter)) then
      best = { alter = alter, octave = octave }
    end
  end
  if not best then return nil end
  return letter .. ACCIDENTALS[best.alter] .. best.octave
end

-- kNoteSpelling can have an entry for each tied part of a note that was respelled, with a propertyOffset of
-- "0:<num>:<den>:0": where that part starts, in quarter notes from the note's start. The note's own spelling, the one
-- stream:dump() shows, is the entry at 0.
local function atStart(offset)
  return offset == nil or offset == "" or offset:match("^0:0:%d+:") ~= nil
end

-- A note or grace note: pitch (sounding MIDI), spelling ("F#5"), and for a grace note its notated duration and
-- whether it is slashed.
function notes.note(ctx, e, node)
  e.pitch = ctx.int(node, "pitch")
  local entries = ctx.read(function(n) return props.entries(ctx.t, n) end, node, "note " .. e.id)
  ctx.score.cache[e] = entries
  local letter
  for _, x in ipairs(entries) do
    if x.property == "kNoteSpelling" and x.layout == -1 and atStart(x.offset) then
      letter = ctx.read(values.string, x.value, "a spelling")
    end
  end
  if not letter or not SEMITONES[letter] then ctx.fail("note " .. e.id .. " has no spelling the reader knows") end
  e.spelling = notes.spelling(letter, e.pitch) or ctx.fail("note " .. e.id .. " is spelled " .. letter
    .. " but sounds MIDI " .. e.pitch)
  if e.kind == "grace" then
    e.notatedDuration = ctx.read(values.position, ctx.text(node, "notatedDuration"), "a notated duration")
    e.slashed = ctx.opt(node, "slashed") == "true"
  end
end

-- A tuplet: actual and normal (3 and 2 for a triplet), over its duration.
function notes.tuplet(ctx, e, node)
  local items = ctx.read(values.list, ctx.text(node, "tupletDefinition"), "a tuplet definition")
  if not (items[1] and items[1].kind == "int" and items[2] and items[2].kind == "int") then
    ctx.fail("tuplet " .. e.id .. " has a definition the reader can't read: " .. ctx.text(node, "tupletDefinition"))
  end
  e.actual, e.normal = items[1].value, items[2].value
end

return notes
