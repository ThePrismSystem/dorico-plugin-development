# Fixtures

The projects the tests read. Each one sits in a folder named for the Dorico version that saved it, and
`versions.json` lists them all with their `fileVersion`, where they came from and who made them. The reader's tests
decode every listed project, so when a Dorico version changes the format, the tests fail on that version's files.

## Built here

`6.2.30/sample.dorico` is built by `build_sample.py` from `sample_data.py`, and `expected.json` records what it
holds. The examples run on it.

`6.2.30/reading.dorico` is built by `build_reading.py` from `make_reading_xml.py`, and `reading.expected.json` records
what it holds. It has one of each kind of item the reader reads, and note properties set five different ways
(through Lua, by command on a selection, by event id, by a menu command, and with a part on screen), so the reader's
tests can tell how Dorico stores each one.

`6.2.30/parallels.dorico` is built by `build_parallels.py` from `make_parallels_xml.py`, and `parallels.expected.json`
lists the findings the parallel fifths recipe should give, worked out by hand. `6.2.30/pickup.dorico` is an import of
`pickup.musicxml`, a one-beat pickup in 4/4, made by `build_pickup.py`. `6.2.30/cautionary.dorico` is built by
`build_cautionary.py` from `make_cautionary_xml.py`, and `cautionary.expected.json` lists the notes the cautionary
accidentals recipe should mark for each set of options, worked out by hand. `6.2.30/texts.dorico` is built by
`build_texts.py` from `make_texts_xml.py`, and `texts.expected.json` lists its texts, lyrics and chord symbols and
what the find and replace recipe should print and change for each row of its tests, worked out by hand.

## From ancientgroove.co.uk

The projects in `6.0.22` to `6.2.20` come from Ben Byram-Wigfield's collection at
<https://ancientgroove.co.uk/dorico/index.html>, which holds music by composers who died more than 70 years ago. The
site says its files "may be freely downloaded and used for any purpose" and asks that modified versions acknowledge
the original creator. They are committed as downloaded, unwrapped from their zip files, so each one shows the format
its Dorico version wrote.

| File | Music | Credit |
| ---- | ----- | ------ |
| `6.0.22/Novello_Lilacs.dorico` | Ivor Novello, *We'll Gather Lilacs* | ancientgroove.co.uk |
| `6.1.0/Purcell_Remember.dorico` | Henry Purcell, *Remember not, Lord, our offences* | Produced by Ben Byram-Wigfield, 2025 |
| `6.1.10/Somervell_Shropshire_Lad.dorico` | Arthur Somervell, *A Shropshire Lad* | Typeset by Ben Byram-Wigfield, released to the public domain (CC0 1.0) |
| `6.2.0/Mozart_Figaro_Sinfonia.dorico` | Mozart, *Le nozze di Figaro*, sinfonia | Transcribed by Ben Byram-Wigfield, 2026 |
| `6.2.20/Faure_Dolly.dorico` | Gabriel Fauré, *Dolly* | Typeset by Ben Byram-Wigfield, 2026 |

## When a new Dorico comes out

Start it with Remote Control on and run `python tools/resave_fixtures.py`. It saves the fixtures built here into a
folder for the new version, adds them to `versions.json`, saves copies of Steinberg's examples into the run folder,
and runs the tests. `python tools/run_tests.py --inputs` reads those copies again later. One test,
`every_fixture_is_a_known_format`, fails until the new `fileVersion` is added to the reader's list of known numbers.
If any other test fails, the new version changed something the reader relies on.
[docs/file-format.md](../docs/file-format.md) says how to do both.
