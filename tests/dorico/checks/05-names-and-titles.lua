-- 05-names-and-titles.lua read the sample's title, flow titles, players, instruments and layouts from a saved copy,
-- names with a comma, an ampersand and a non-ASCII letter included.
local checks = require("checks")

-- The sample's instruments: the MusicXML part names, without the "(B{@flat@})" Dorico adds to the trumpet player's
-- name, and their ids in Dorico's instrument library.
local INSTRUMENTS = {
  "Flute (instrument.wind.flute), sounds as written",
  "Trumpet Zoë (instrument.brass.trumpet.bflat), transposes 1 steps, 2 semitones, 0 octaves",
  "Violin, solo & tutti (instrument.strings.violin), sounds as written",
  "Piano (instrument.keyboard.piano), sounds as written",
}

return function(p, run)
  local want = checks.expected()
  p:check("the project's title", checks.printed(run, "project: Sample"))
  for n, flow in ipairs(want.flows) do
    p:check("flow " .. n .. "'s title", checks.printed(run, "flow " .. n .. ": " .. flow.title))
  end
  for n, player in ipairs(want.flows[1].players) do
    p:check("player " .. n, checks.printed(run, "player " .. n .. ": " .. player.name))
    p:check("player " .. n .. "'s part", checks.printed(run, "layout " .. n .. ": " .. player.name .. " (part)"))
  end
  for n, line in ipairs(INSTRUMENTS) do
    p:check("instrument " .. n, checks.printed(run, "instrument " .. n .. ": " .. line))
  end
  p:check("the full score", checks.printed(run, "layout 0: Full score (full score)"))
end
