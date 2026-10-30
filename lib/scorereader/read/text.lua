-- Staff and system text, lyrics, and chord symbols.
local tree = require("scorereader.tree")

local text = {}

-- {{style, fragments = {{text, style, localStyle}}}} from a content or richText node, and the words, paragraphs
-- joined by newlines.
local function paragraphsOf(ctx, node)
  local t, paragraphs, lines = ctx.t, {}, {}
  local list = tree.child(t, node, "paragraphs")
  for _, p in ipairs(list and tree.children(t, list) or {}) do
    local para, words = { style = ctx.opt(p, "paragraphStyleID") or "", fragments = {} }, {}
    local frags = tree.child(t, p, "fragments")
    for _, f in ipairs(frags and tree.children(t, frags) or {}) do
      local style = ctx.opt(f, "textFragmentStyle/libraryStyle")
      local frag = { text = ctx.opt(f, "content") or "", style = style ~= "" and style or nil,
        localStyle = tree.path(t, f, "textFragmentStyle/localStyle") ~= nil }
      para.fragments[#para.fragments + 1] = frag
      words[#words + 1] = frag.text
    end
    paragraphs[#paragraphs + 1] = para
    lines[#lines + 1] = table.concat(words)
  end
  return paragraphs, table.concat(lines, "\n")
end

-- Whether a text has formatting beyond its paragraph style: more than one fragment, or a fragment with a style of its
-- own. Rebuilding such a text with createText would lose that.
local function formatted(paragraphs)
  for _, p in ipairs(paragraphs) do
    if #p.fragments > 1 then return true end
    for _, f in ipairs(p.fragments) do
      if f.style or f.localStyle then return true end
    end
  end
  return false
end

-- words, paragraphs, above, system, formatted.
function text.text(ctx, e, node)
  e.paragraphs, e.words = paragraphsOf(ctx, ctx.node(node, "content"))
  e.above = ctx.text(node, "aboveOrBelow") == "kAbove"
  e.system = ctx.text(node, "isSystemText") == "true"
  e.formatted = formatted(e.paragraphs)
end

local SYLLABLES = { kStart = "begin", kMiddle = "middle", kEnd = "end", kWholeWord = "single" }
local LINE_TYPES = { kVerse = "verse", kChorus = "chorus" }

-- text, syllable (begin, middle, end, single, as MusicXML names them), line (from 1), lineType (verse or chorus),
-- above. A melisma is the event's duration.
function text.lyric(ctx, e, node)
  local id = ctx.int(node, "lyricElementID")
  local el = (ctx.flow.elements.LyricElementTableDefinition or {})[id]
    or ctx.fail("lyric " .. e.id .. " points to no element " .. id)
  e.text = ctx.text(el, "text")
  local raw = ctx.text(el, "syllableType")
  e.syllable = SYLLABLES[raw] or ctx.fail("lyric " .. e.id .. " has a syllable type the reader doesn't know: " .. raw)
  e.line = ctx.int(el, "lineNumber") + 1
  local lineType = ctx.text(el, "lineType")
  e.lineType = LINE_TYPES[lineType] or ctx.fail("lyric " .. e.id .. " has a line type the reader doesn't know: "
    .. lineType)
  e.above = ctx.text(el, "lineLocation") == "kAbove"
end

local ACCIDENTALS = { kNatural = "", kSharp = "#", kFlat = "b", kDoubleSharp = "##", kDoubleFlat = "bb" }
local QUALITIES = { kMajor = "major", kMinor = "minor", kAugmented = "augmented", kDiminished = "diminished" }
local SUFFIX = { major = "", minor = "m", augmented = "+", diminished = "dim" }
local INTERVALS = { kNone = "", k7 = "7", kMaj7 = "maj7", k6 = "6", k9 = "9", k11 = "11", k13 = "13" }

-- root ("G", "F#"), quality, interval, and a name ("G7", "Am") when the chord has no alterations and its quality and
-- interval are ones the reader knows; only major, minor and the dominant seventh are checked against Dorico's own
-- names so far. rawQuality and rawInterval are always there.
function text.chordSymbol(ctx, e, node)
  local chord = ctx.node(node, "chordSymbolData/primaryChord")
  local accidental = ctx.text(chord, "root/accidentalType")
  e.root = ctx.text(chord, "root/noteName") .. (ACCIDENTALS[accidental]
    or ctx.fail("chord symbol " .. e.id .. " has an accidental the reader doesn't know: " .. accidental))
  e.rawQuality, e.rawInterval = ctx.text(chord, "definition/quality"), ctx.text(chord, "definition/interval")
  e.quality, e.interval = QUALITIES[e.rawQuality], INTERVALS[e.rawInterval]
  local alterations = tree.path(ctx.t, chord, "definition/alterations")
  e.altered = alterations ~= nil and #tree.children(ctx.t, alterations) > 0
  if e.quality and e.interval and not e.altered then e.name = e.root .. SUFFIX[e.quality] .. e.interval end
end

return text
