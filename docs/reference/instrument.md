# Instruments

A player's instrument, and a flow's.

[The reference's index](README.md#reading-the-tables) explains the Kind and Status columns. Don't try a member
marked "not tried" on a project you care about: a bad call can crash Dorico.

## `DoCore.Instrument`

| Member | Kind | Status | Notes |
| ------ | ---- | ------ | ----- |
| `__eq` | operator | not tried |  |
| `__len` | operator | not tried |  |
| `__tostring` | operator | not tried |  |
| `id` | property | verified | Unique, and doesn't change; often the player's id too. |
| `name` | property | fails | Raises an error, as `tostring` does (the handbells plug-in's probes). |

## `DoCore.FlowInstrument`

| Member | Kind | Status | Notes |
| ------ | ---- | ------ | ----- |
| `__eq` | operator | not tried |  |
| `__len` | operator | not tried |  |
| `__tostring` | operator | not tried |  |
| `id` | property | verified | The instrument's id ([02-walk-the-score](../../examples/fundamentals/02-walk-the-score.lua)). |
| `name` | member | not tried |  |
| `streams` | property | fails | Returns streams only for the first instrument, and an empty list for the rest. |
