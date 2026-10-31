# Players

A player.

[The reference's index](README.md#reading-the-tables) explains the Kind and Status columns. Don't try a member
marked "not tried" on a project you care about: a bad call can crash Dorico.

## `DoCore.Player`

| Member | Kind | Status | Notes |
| ------ | ---- | ------ | ----- |
| `__len` | operator | not tried |  |
| `__tostring` | operator | verified | `tostring(player)` is the player's name, with music symbols as tokens such as `{@flat@}`. |
| `instruments` | property | verified | The player's instruments; the first one's `id` stands in for the player ([02-walk-the-score](../../examples/fundamentals/02-walk-the-score.lua)). |
