# Properties

An event's property table, and the context its calls take.

Members come from `spikes/class_members.lua`'s scan of Lua's registry, sorted by `tools/members.py` into
[members.json](members.json). "Member" in the Kind column means the scan can't tell a property from a method, since
luabind stores both as functions, and nobody has tried it. Status says whether an example or probe has used a member
(verified), found it broken (fails), or left it alone (not tried). Don't try a member on a project you care about:
a bad call can crash Dorico.

## `DoCore.EventPropertyTable`

| Member | Kind | Status | Notes |
| ------ | ---- | ------ | ----- |
| `__len` | operator | not tried |  |
| `__tostring` | operator | not tried |  |
| `get` | method | verified | `get(name, context)` returns a Variant; `""` when unset ([04-noteheads-and-colours](../../examples/fundamentals/04-noteheads-and-colours.lua)). |
| `getPropertyNames` | method | verified | The properties the event has, not every one it could have. |
| `set` | method | verified | `set(name, variant, context)` returns true when Dorico took the value; undoable like any edit. |

## `DoCore.EventPropertyEntry`

| Member | Kind | Status | Notes |
| ------ | ---- | ------ | ----- |
| `__init` | constructor | not tried |  |
| `__init` | constructor | not tried |  |
| `__len` | operator | not tried |  |
| `__tostring` | operator | not tried |  |
| `context` | member | not tried |  |
| `name` | member | not tried |  |
| `value` | member | not tried |  |

## `DoCore.PropertyContext`

| Member | Kind | Status | Notes |
| ------ | ---- | ------ | ----- |
| `__init` | constructor | verified | `DoCore.PropertyContext()`, for `get` and `set`. |
