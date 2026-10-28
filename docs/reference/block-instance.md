# Blocks and block instances

What `EventEdit.Select` needs to find an event.

Members come from `spikes/class_members.lua`'s scan of Lua's registry, sorted by `tools/members.py` into
[members.json](members.json). "Member" in the Kind column means the scan can't tell a property from a method, since
luabind stores both as functions, and nobody has tried it. Status says whether an example or probe has used a member
(verified), found it broken (fails), or left it alone (not tried). Don't try a member on a project you care about:
a bad call can crash Dorico.

## `DoCore.EventBlockInstance`

| Member | Kind | Status | Notes |
| ------ | ---- | ------ | ----- |
| `__eq` | operator | not tried |  |
| `__len` | operator | not tried |  |
| `__tostring` | operator | not tried |  |
| `block` | property | verified | Its block, whose `id` is what `EventEdit.Select` takes ([08-select-by-id](../../examples/fundamentals/08-select-by-id.lua)). |
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
| `id` | property | verified | `EventEdit.Select`'s `EventBlockID` ([08-select-by-id](../../examples/fundamentals/08-select-by-id.lua)). |
