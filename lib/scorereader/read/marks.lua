-- Tempos, playing techniques and clefs.
local marks = {}

-- text ("Allegro"), type (kAbsolute, kRelative), and for an absolute tempo microsecondsPerBeat and bpm. The bpm
-- assumes the beat is the tempo's own beat unit, as for the reading fixture's quarter-note 120.
function marks.tempo(ctx, e, node)
  e.text = ctx.opt(node, "data/text") or ""
  e.type = ctx.opt(node, "data/type")
  e.preset = ctx.opt(node, "data/presetID")
  local value = tonumber(ctx.opt(node, "data/absoluteTempo/tempoValue") or "")
  if value and value > 0 then
    e.microsecondsPerBeat = value
    e.bpm = math.floor(60000000 / value + 0.5)
  end
end

-- appearance (the library entity, "pta.pizzText"), name ("Pizzicato"), text ("pizz") and technique ("pt.pizzicato").
function marks.technique(ctx, e, node)
  e.appearance = ctx.text(node, "appearanceEntityID")
  local def = ctx.score.library[e.appearance]
  if def then
    e.name = def.name
    e.text = ctx.opt(def.node, "text")
    e.technique = ctx.opt(def.node, "playingTechniqueEntityID")
  end
end

-- clef: the clef's entity ("clef.treble").
function marks.clef(ctx, e, node)
  e.clef = ctx.opt(node, "entityIDs/idForTransposingLayouts")
end

return marks
