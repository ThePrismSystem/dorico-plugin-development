# Blocks and block instances

What `EventEdit.Select` needs to find an event.

[The reference's index](README.md#reading-the-tables) explains the Kind and Status columns. Don't try a member
marked "not tried" on a project you care about: a bad call can crash Dorico.

## `DoCore.EventBlockInstance`

| Member | Kind | Status | Notes |
| ------ | ---- | ------ | ----- |
| `__eq` | operator | not tried |  |
| `__len` | operator | not tried |  |
| `__tostring` | operator | not tried |  |
| `block` | property | verified | Its block, whose `id` is what `EventEdit.Select` takes ([12-select-by-id](../../examples/fundamentals/12-select-by-id.lua)). |
| `events` | member | not tried |  |
| `id` | property | verified | The dump's "Start block id". |
| `position` | member | not tried |  |

## `DoCore.EventBlock`

| Member | Kind | Status | Notes |
| ------ | ---- | ------ | ----- |
| `__eq` | operator | not tried |  |
| `__len` | operator | not tried |  |
| `__tostring` | operator | not tried |  |
| `events` | member | not tried |  |
| `id` | property | verified | `EventEdit.Select`'s `EventBlockID` ([12-select-by-id](../../examples/fundamentals/12-select-by-id.lua)). |
