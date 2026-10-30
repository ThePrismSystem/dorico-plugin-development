-- Time and key signatures, from the flow's bar division and tonality division elements.
local values = require("scorereader.values")

local signatures = {}

-- numerator and denominator of the first time signature, or barlineOnly when the bar division's list of time
-- signatures is empty, as when it changes only a barline or a bar number; barline is the barline change's type when
-- there is one; pickup is the length of a short first bar, such as a one-beat pickup, when Dorico stores one
-- (irregularBarLength).
function signatures.time(ctx, e, node)
  local el = ctx.element(e, node, "barDivisionElementID", "BarDivisionElementTableDefinition", "bar division")
  local first = ctx.list(el, "barDivisionData/timeSignature/timeSignaturesAndDivisions")[1]
  if first then
    local numerator = ctx.text(first, "timeSignature/numerator")
    e.numerator = tonumber(numerator) or numerator
    e.denominator = ctx.int(first, "timeSignature/denominator")
  else
    e.barlineOnly = true
  end
  e.barline = ctx.opt(el, "barDivisionData/barlineChangeIfAny/type")
  local pickup = ctx.opt(el, "barDivisionData/irregularBarLength")
  if pickup then e.pickup = ctx.read(values.position, pickup, "a pickup length") end
end

local LETTERS = "FCGDAEB"
local ACCIDENTALS = { natural = 0, sharp = 1, flat = -1, doublesharp = 2, doubleflat = -2 }
local MODES = { kKeySigMajor = "major", kKeySigMinor = "minor", kKeySigAtonal = "atonal", kKeySigCustom = "custom" }

-- mode (major, minor, atonal or custom), the root's accidentalID as Dorico names it, and root ("G", "F#") and fifths
-- (sharps positive, flats negative) for a major or minor key in the usual 12-note system. Atonal keys have no root, and
-- neither do keys in another tonality system: Steinberg's Smith example spells its flats
-- accidental.24et.western.flat.gould, which the reader hasn't matched to a 12-note accidental.
function signatures.key(ctx, e, node)
  local el = ctx.element(e, node, "tonalityDivisionElementID", "TonalityDivisionElementTableDefinition",
    "tonality division")
  local key = ctx.node(el, "tonalityDivisionData/keySignature")
  local rawMode = ctx.text(key, "root/tonalityType")
  e.mode = MODES[rawMode] or ctx.fail("key " .. e.id .. " has a type the reader doesn't know: " .. rawMode)
  e.atonal = e.mode == "atonal"
  local letter = ctx.opt(key, "root/root/noteName")
  if not letter then
    if e.mode == "major" or e.mode == "minor" then
      ctx.fail("key " .. e.id .. " is " .. e.mode .. " but has no root")
    end
    return
  end
  local accidentalId = ctx.text(key, "root/root/accidentalID")
  local alter = ACCIDENTALS[accidentalId:match("^accidental%.12et%.western%.(%a+)$") or ""]
  e.accidentalID = accidentalId
  if alter == nil then return end
  e.root = letter .. (alter > 0 and string.rep("#", alter) or string.rep("b", -alter))
  local index = LETTERS:find(letter, 1, true)
  if index and (e.mode == "major" or e.mode == "minor") then
    e.fifths = (index - 2) + 7 * alter - (e.mode == "minor" and 3 or 0)
  end
end

return signatures
