-- After note-names.lua on the reading fixture with English names below the staff: every chord of every voice has one
-- text with its names, below the staff, and the fixture's own texts are still there. The spot checks were worked out
-- by hand: the flute's C5 is "C", the clarinet's sounding D5 is "E" written (or "D" with args.sounding), the guitar's
-- C3 is "C", and the piano's E5 and G5 make "G" over "E".
local checks = require("checks")

return function(p, run, args)
  local s, score, values = checks.savedCopy()
  local names = checks.helper("examples/recipes/note-names.lua", { "names" }, "names")
  local wrong, count, spot, firstVoice = {}, 0, {}, {}
  for _, flow in ipairs(s.flows) do
    for _, stream in ipairs(flow.streams) do
      if stream.type == "voice" then
        local player = score.ownerOf(s, stream.events[1] or { streamId = stream.id }) or {}
        if flow == s.flows[1] and player.name and not firstVoice[player.name] then
          firstVoice[player.name] = stream.id
        end
        local chords, texts = {}, {}
        for _, e in ipairs(stream.events) do
          local k = values.positionText(e.position)
          if e.kind == "note" then chords[k] = chords[k] or {}; table.insert(chords[k], e) end
          if e.kind == "text" then texts[k] = texts[k] or {}; table.insert(texts[k], e) end
        end
        local instrument = s.instruments[stream.instrumentId]
        local t = not args.sounding and instrument and instrument.transposition or nil
        for k, notes in pairs(chords) do
          local spellings = {}
          for i, e in ipairs(notes) do spellings[i] = names.written(e.spelling, t) end
          local want, found = names.chord(spellings, "english", {}), 0
          for _, x in ipairs(texts[k] or {}) do
            if x.words == want then
              found = found + 1
              if score.above(s, x, s.layouts[1].id) then wrong[#wrong + 1] = stream.id .. "@" .. k .. " is above" end
            end
          end
          if found ~= 1 then wrong[#wrong + 1] = stream.id .. "@" .. k .. " has " .. found .. " " .. want end
          count = count + 1
          spot[stream.id .. "@" .. k] = want
        end
      end
    end
  end
  p:check("one name below each chord", #wrong == 0 and count > 50, count .. ": " .. table.concat(wrong, " / "))
  local function at(player) return spot[(firstVoice[player] or "?") .. "@0"] end
  p:check("the flute's C5", at("Flute") == "C", at("Flute"))
  p:check("the clarinet's D5", at("Clarinet (B{@flat@})") == (args.sounding and "D" or "E"), at("Clarinet (B{@flat@})"))
  p:check("the guitar's C3", at("Guitar") == "C", at("Guitar"))
  p:check("the piano's chord", at("Piano") == "G\nE", at("Piano"))
  local kept = {}
  for _, e in ipairs(s.flows[1].events) do
    if e.kind == "text" then kept[e.words] = true end
  end
  for _, want in ipairs(checks.reading().texts) do p:check("kept " .. want.words, kept[want.words]) end
  p:check("said how many", checks.printed(run, string.format("Wrote %d names; removed 0 old ones.", count))
    or (args.second and run.printed[#run.printed]:find("^Wrote " .. count .. " names; removed " .. count)),
    run.printed[#run.printed])
end
