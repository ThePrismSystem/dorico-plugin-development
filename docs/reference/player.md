# Players

A player.

Members come from `spikes/class_members.lua`'s scan of Lua's registry, sorted by `tools/members.py` into
[members.json](members.json). "Member" in the Kind column means the scan can't tell a property from a method, since
luabind stores both as functions, and nobody has tried it. Status says whether an example or probe has used a member
(verified), found it broken (fails), or left it alone (not tried). Don't try a member on a project you care about:
a bad call can crash Dorico.

## `DoCore.Player`

| Member | Kind | Status | Notes |
| ------ | ---- | ------ | ----- |
| `__len` | operator | not tried |  |
| `__tostring` | operator | verified | `tostring(player)` is the player's name, with music symbols as tokens such as `{@flat@}`. |
| `instruments` | property | verified | The player's instruments; the first one's `id` stands in for the player ([02-walk-the-score](../../examples/fundamentals/02-walk-the-score.lua)). |
