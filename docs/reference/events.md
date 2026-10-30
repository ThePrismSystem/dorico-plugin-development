# Events

The events in a stream. Every kind has the base event's members; some add their own.

Members come from `spikes/class_members.lua`'s scan of Lua's registry, sorted by `tools/members.py` into
[members.json](members.json). "Member" in the Kind column means the scan can't tell a property from a method, since
luabind stores both as functions, and nobody has tried it. Status says whether an example or probe has used a member
(verified), found it broken (fails), or left it alone (not tried). Don't try a member on a project you care about:
a bad call can crash Dorico.

## `DoCore.Event`

| Member | Kind | Status | Notes |
| ------ | ---- | ------ | ----- |
| `__eq` | operator | not tried |  |
| `__len` | operator | not tried |  |
| `__tostring` | operator | verified | Describes the event, as a dump line ends: `kNoteEvent (id:7932) at 0, duration 1  E5 (ends 1)`. |
| `duration` | member | not tried |  |
| `endPosition` | member | not tried |  |
| `id` | property | verified | What `EventEdit.Select` takes as `EventID` ([04-noteheads-and-colours](../../examples/fundamentals/04-noteheads-and-colours.lua)). |
| `position` | member | not tried |  |
| `propertyTable` | property | verified | The event's properties ([04-noteheads-and-colours](../../examples/fundamentals/04-noteheads-and-colours.lua)). |

## `DoCore.NoteEvent`

| Member | Kind | Status | Notes |
| ------ | ---- | ------ | ----- |
| `__eq` | operator | not tried |  |
| `__len` | operator | not tried |  |
| `__tostring` | operator | verified | Describes the event, as a dump line ends: `kNoteEvent (id:7932) at 0, duration 1  E5 (ends 1)`. |
| `duration` | member | not tried |  |
| `endPosition` | member | not tried |  |
| `id` | property | verified | What `EventEdit.Select` takes as `EventID` ([04-noteheads-and-colours](../../examples/fundamentals/04-noteheads-and-colours.lua)). |
| `pitchWithSpelling` | member | not tried |  |
| `position` | member | not tried |  |
| `propertyTable` | property | verified | The event's properties ([04-noteheads-and-colours](../../examples/fundamentals/04-noteheads-and-colours.lua)). |

## `DoCore.GraceNoteEvent`

| Member | Kind | Status | Notes |
| ------ | ---- | ------ | ----- |
| `__eq` | operator | not tried |  |
| `__len` | operator | not tried |  |
| `__tostring` | operator | verified | Describes the event, as a dump line ends: `kNoteEvent (id:7932) at 0, duration 1  E5 (ends 1)`. |
| `duration` | member | not tried |  |
| `endPosition` | member | not tried |  |
| `id` | property | verified | What `EventEdit.Select` takes as `EventID` ([04-noteheads-and-colours](../../examples/fundamentals/04-noteheads-and-colours.lua)). |
| `pitchWithSpelling` | member | not tried |  |
| `position` | member | not tried |  |
| `propertyTable` | property | verified | The event's properties ([04-noteheads-and-colours](../../examples/fundamentals/04-noteheads-and-colours.lua)). |
| `secondaryPosition` | member | not tried |  |

## `DoCore.RestEvent`

| Member | Kind | Status | Notes |
| ------ | ---- | ------ | ----- |
| `__eq` | operator | not tried |  |
| `__len` | operator | not tried |  |
| `__tostring` | operator | not tried | As on the base event; no example reads this kind. |
| `duration` | member | not tried |  |
| `endPosition` | member | not tried |  |
| `id` | property | not tried | As on the base event; no example reads this kind. |
| `position` | member | not tried |  |
| `propertyTable` | property | not tried | As on the base event; no example reads this kind. |

## `DoCore.BarRestEvent`

| Member | Kind | Status | Notes |
| ------ | ---- | ------ | ----- |
| `__eq` | operator | not tried |  |
| `__len` | operator | not tried |  |
| `__tostring` | operator | not tried | As on the base event; no example reads this kind. |
| `duration` | member | not tried |  |
| `endPosition` | member | not tried |  |
| `id` | property | not tried | As on the base event; no example reads this kind. |
| `position` | member | not tried |  |
| `propertyTable` | property | not tried | As on the base event; no example reads this kind. |

## `DoCore.TextEvent`

| Member | Kind | Status | Notes |
| ------ | ---- | ------ | ----- |
| `__eq` | operator | not tried |  |
| `__len` | operator | not tried |  |
| `__tostring` | operator | not tried | As on the base event; no example reads this kind. |
| `duration` | member | not tried |  |
| `endPosition` | member | not tried |  |
| `id` | property | not tried | As on the base event; no example reads this kind. |
| `position` | member | not tried |  |
| `propertyTable` | property | not tried | As on the base event; no example reads this kind. |
| `text` | member | not tried |  |

## `DoCore.TupletEvent`

| Member | Kind | Status | Notes |
| ------ | ---- | ------ | ----- |
| `__eq` | operator | not tried |  |
| `__len` | operator | not tried |  |
| `__tostring` | operator | not tried | As on the base event; no example reads this kind. |
| `duration` | member | not tried |  |
| `endPosition` | member | not tried |  |
| `id` | property | not tried | As on the base event; no example reads this kind. |
| `position` | member | not tried |  |
| `propertyTable` | property | not tried | As on the base event; no example reads this kind. |
| `tupletDef` | member | not tried |  |

## `DoCore.ClefEvent`

| Member | Kind | Status | Notes |
| ------ | ---- | ------ | ----- |
| `__eq` | operator | not tried |  |
| `__len` | operator | not tried |  |
| `__tostring` | operator | not tried | As on the base event; no example reads this kind. |
| `duration` | member | not tried |  |
| `endPosition` | member | not tried |  |
| `id` | property | not tried | As on the base event; no example reads this kind. |
| `nonTransposingClefEntity` | member | not tried |  |
| `position` | member | not tried |  |
| `propertyTable` | property | not tried | As on the base event; no example reads this kind. |
| `transposingClefEntity` | member | not tried |  |

## `DoCore.OttavaLineEvent`

| Member | Kind | Status | Notes |
| ------ | ---- | ------ | ----- |
| `__eq` | operator | not tried |  |
| `__len` | operator | not tried |  |
| `__tostring` | operator | not tried | As on the base event; no example reads this kind. |
| `duration` | member | not tried |  |
| `endPosition` | member | not tried |  |
| `id` | property | not tried | As on the base event; no example reads this kind. |
| `ottavaLineDefinitionID` | member | not tried |  |
| `position` | member | not tried |  |
| `propertyTable` | property | not tried | As on the base event; no example reads this kind. |

## `DoCore.BreakEvent`

| Member | Kind | Status | Notes |
| ------ | ---- | ------ | ----- |
| `__eq` | operator | not tried |  |
| `__len` | operator | not tried |  |
| `__tostring` | operator | not tried | As on the base event; no example reads this kind. |
| `duration` | member | not tried |  |
| `endPosition` | member | not tried |  |
| `id` | property | not tried | As on the base event; no example reads this kind. |
| `isFrameBreak` | member | not tried |  |
| `isSystemBreak` | member | not tried |  |
| `layoutID` | member | not tried |  |
| `position` | member | not tried |  |
| `propertyTable` | property | not tried | As on the base event; no example reads this kind. |

## `DoCore.BarDivisionEvent`

| Member | Kind | Status | Notes |
| ------ | ---- | ------ | ----- |
| `__eq` | operator | not tried |  |
| `__len` | operator | not tried |  |
| `__tostring` | operator | not tried | As on the base event; no example reads this kind. |
| `duration` | member | not tried |  |
| `endPosition` | member | not tried |  |
| `id` | property | not tried | As on the base event; no example reads this kind. |
| `position` | member | not tried |  |
| `propertyTable` | property | not tried | As on the base event; no example reads this kind. |

## `DoCore.TonalityDivisionEvent`

| Member | Kind | Status | Notes |
| ------ | ---- | ------ | ----- |
| `__eq` | operator | not tried |  |
| `__len` | operator | not tried |  |
| `__tostring` | operator | not tried | As on the base event; no example reads this kind. |
| `duration` | member | not tried |  |
| `endPosition` | member | not tried |  |
| `id` | property | not tried | As on the base event; no example reads this kind. |
| `position` | member | not tried |  |
| `propertyTable` | property | not tried | As on the base event; no example reads this kind. |
| `tonalityDivisionElementID` | member | not tried |  |

## `DoCore.DynamicGroupEvent`

| Member | Kind | Status | Notes |
| ------ | ---- | ------ | ----- |
| `__eq` | operator | not tried |  |
| `__len` | operator | not tried |  |
| `__tostring` | operator | not tried | As on the base event; no example reads this kind. |
| `duration` | member | not tried |  |
| `endPosition` | member | not tried |  |
| `id` | property | not tried | As on the base event; no example reads this kind. |
| `position` | member | not tried |  |
| `propertyTable` | property | not tried | As on the base event; no example reads this kind. |
