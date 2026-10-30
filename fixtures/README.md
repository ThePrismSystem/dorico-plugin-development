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
