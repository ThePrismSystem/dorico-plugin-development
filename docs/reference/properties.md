# Properties

An event's property table, and the context its calls take.

[The reference's index](README.md#reading-the-tables) explains the Kind and Status columns. Don't try a member
marked "not tried" on a project you care about: a bad call can crash Dorico.

## `DoCore.EventPropertyTable`

| Member | Kind | Status | Notes |
| ------ | ---- | ------ | ----- |
| `__len` | operator | not tried |  |
| `__tostring` | operator | not tried |  |
| `get` | method | verified | `get(name, context)` returns a Variant; `""` when unset ([S8](../spikes.md#s8-reading-and-setting-note-properties)). |
| `getPropertyNames` | method | verified | The properties the event has, not every one it could have. |
| `set` | method | verified | `set(name, variant, context)` returns true when Dorico took the value; undoable like any edit. |

## `DoCore.EventPropertyEntry`

| Member | Kind | Status | Notes |
| ------ | ---- | ------ | ----- |
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
