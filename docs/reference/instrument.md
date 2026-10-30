# Instruments

A player's instrument, and a flow's.

Members come from `spikes/class_members.lua`'s scan of Lua's registry, sorted by `tools/members.py` into
[members.json](members.json). "Member" in the Kind column means the scan can't tell a property from a method, since
luabind stores both as functions, and nobody has tried it. Status says whether an example or probe has used a member
(verified), found it broken (fails), or left it alone (not tried). Don't try a member on a project you care about:
a bad call can crash Dorico.

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
