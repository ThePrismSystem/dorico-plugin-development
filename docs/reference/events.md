# Events

The events in a stream. Every kind has the base event's members; some add their own.

[The reference's index](README.md#reading-the-tables) explains the Kind and Status columns. Don't try a member
marked "not tried" on a project you care about: a bad call can crash Dorico.

## `DoCore.Event`

| Member | Kind | Status | Notes |
| ------ | ---- | ------ | ----- |
| `__eq` | operator | not tried |  |
| `__len` | operator | not tried |  |
| `__tostring` | operator | verified | Describes the event, as a dump line ends: `kNoteEvent (id:7932) at 0, duration 1  E5 (ends 1)`. |
| `duration` | member | not tried |  |
| `endPosition` | member | not tried |  |
| `id` | property | verified | What `EventEdit.Select` takes as `EventID` ([S8](../spikes.md#s8-reading-and-setting-note-properties)). |
| `position` | member | not tried |  |
| `propertyTable` | property | verified | The event's properties ([S8](../spikes.md#s8-reading-and-setting-note-properties)). |

## `DoCore.NoteEvent`

| Member | Kind | Status | Notes |
| ------ | ---- | ------ | ----- |
| `__eq` | operator | not tried |  |
| `__len` | operator | not tried |  |
| `__tostring` | operator | verified | Describes the event, as a dump line ends: `kNoteEvent (id:7932) at 0, duration 1  E5 (ends 1)`. |
| `duration` | member | not tried |  |
| `endPosition` | member | not tried |  |
| `id` | property | verified | What `EventEdit.Select` takes as `EventID` ([S8](../spikes.md#s8-reading-and-setting-note-properties)). |
| `pitchWithSpelling` | member | not tried |  |
| `position` | member | not tried |  |
| `propertyTable` | property | verified | The event's properties ([S8](../spikes.md#s8-reading-and-setting-note-properties)). |

## `DoCore.GraceNoteEvent`

| Member | Kind | Status | Notes |
| ------ | ---- | ------ | ----- |
| `__eq` | operator | not tried |  |
| `__len` | operator | not tried |  |
| `__tostring` | operator | verified | Describes the event, as a dump line ends: `kNoteEvent (id:7932) at 0, duration 1  E5 (ends 1)`. |
| `duration` | member | not tried |  |
| `endPosition` | member | not tried |  |
| `id` | property | verified | What `EventEdit.Select` takes as `EventID` ([S8](../spikes.md#s8-reading-and-setting-note-properties)). |
| `pitchWithSpelling` | member | not tried |  |
| `position` | member | not tried |  |
| `propertyTable` | property | verified | The event's properties ([S8](../spikes.md#s8-reading-and-setting-note-properties)). |
| `secondaryPosition` | member | not tried |  |

## `DoCore.RestEvent`

| Member | Kind | Status | Notes |
| ------ | ---- | ------ | ----- |
| `__eq` | operator | not tried |  |
| `__len` | operator | not tried |  |
| `__tostring` | operator | not tried | As on the base event; not tried on this kind. |
| `duration` | member | not tried |  |
| `endPosition` | member | not tried |  |
| `id` | property | not tried | As on the base event; not tried on this kind. |
| `position` | member | not tried |  |
| `propertyTable` | property | not tried | As on the base event; not tried on this kind. |

## `DoCore.BarRestEvent`

| Member | Kind | Status | Notes |
| ------ | ---- | ------ | ----- |
| `__eq` | operator | not tried |  |
| `__len` | operator | not tried |  |
| `__tostring` | operator | not tried | As on the base event; not tried on this kind. |
| `duration` | member | not tried |  |
| `endPosition` | member | not tried |  |
| `id` | property | not tried | As on the base event; not tried on this kind. |
| `position` | member | not tried |  |
| `propertyTable` | property | not tried | As on the base event; not tried on this kind. |

## `DoCore.TextEvent`

| Member | Kind | Status | Notes |
| ------ | ---- | ------ | ----- |
| `__eq` | operator | not tried |  |
| `__len` | operator | not tried |  |
| `__tostring` | operator | verified | `TextEvent ID: 326 kTextEvent (id:326) at 0 : <words>`, then the paragraph style on a line of its own ([text_event.lua](../spikes.md#texteventtext)). |
| `duration` | member | not tried |  |
| `endPosition` | member | not tried |  |
| `id` | property | not tried | As on the base event; not tried on this kind. |
| `position` | member | not tried |  |
| `propertyTable` | property | not tried | As on the base event; not tried on this kind. |
| `text` | member | verified | The words, as a string. Read-only: setting it raises "property 'text' is read only" ([text_event.lua](../spikes.md#texteventtext)). |

## `DoCore.TupletEvent`

| Member | Kind | Status | Notes |
| ------ | ---- | ------ | ----- |
| `__eq` | operator | not tried |  |
| `__len` | operator | not tried |  |
| `__tostring` | operator | not tried | As on the base event; not tried on this kind. |
| `duration` | member | not tried |  |
| `endPosition` | member | not tried |  |
| `id` | property | not tried | As on the base event; not tried on this kind. |
| `position` | member | not tried |  |
| `propertyTable` | property | not tried | As on the base event; not tried on this kind. |
| `tupletDef` | member | not tried |  |

## `DoCore.ClefEvent`

| Member | Kind | Status | Notes |
| ------ | ---- | ------ | ----- |
| `__eq` | operator | not tried |  |
| `__len` | operator | not tried |  |
| `__tostring` | operator | not tried | As on the base event; not tried on this kind. |
| `duration` | member | not tried |  |
| `endPosition` | member | not tried |  |
| `id` | property | not tried | As on the base event; not tried on this kind. |
| `nonTransposingClefEntity` | member | not tried |  |
| `position` | member | not tried |  |
| `propertyTable` | property | not tried | As on the base event; not tried on this kind. |
| `transposingClefEntity` | member | not tried |  |

## `DoCore.OttavaLineEvent`

| Member | Kind | Status | Notes |
| ------ | ---- | ------ | ----- |
| `__eq` | operator | not tried |  |
| `__len` | operator | not tried |  |
| `__tostring` | operator | not tried | As on the base event; not tried on this kind. |
| `duration` | member | not tried |  |
| `endPosition` | member | not tried |  |
| `id` | property | not tried | As on the base event; not tried on this kind. |
| `ottavaLineDefinitionID` | member | not tried |  |
| `position` | member | not tried |  |
| `propertyTable` | property | not tried | As on the base event; not tried on this kind. |

## `DoCore.BreakEvent`

| Member | Kind | Status | Notes |
| ------ | ---- | ------ | ----- |
| `__eq` | operator | not tried |  |
| `__len` | operator | not tried |  |
| `__tostring` | operator | not tried | As on the base event; not tried on this kind. |
| `duration` | member | not tried |  |
| `endPosition` | member | not tried |  |
| `id` | property | not tried | As on the base event; not tried on this kind. |
| `isFrameBreak` | member | not tried |  |
| `isSystemBreak` | member | not tried |  |
| `layoutID` | member | not tried |  |
| `position` | member | not tried |  |
| `propertyTable` | property | not tried | As on the base event; not tried on this kind. |

## `DoCore.BarDivisionEvent`

| Member | Kind | Status | Notes |
| ------ | ---- | ------ | ----- |
| `__eq` | operator | not tried |  |
| `__len` | operator | not tried |  |
| `__tostring` | operator | not tried | As on the base event; not tried on this kind. |
| `duration` | member | not tried |  |
| `endPosition` | member | not tried |  |
| `id` | property | not tried | As on the base event; not tried on this kind. |
| `position` | member | not tried |  |
| `propertyTable` | property | not tried | As on the base event; not tried on this kind. |

## `DoCore.TonalityDivisionEvent`

| Member | Kind | Status | Notes |
| ------ | ---- | ------ | ----- |
| `__eq` | operator | not tried |  |
| `__len` | operator | not tried |  |
| `__tostring` | operator | not tried | As on the base event; not tried on this kind. |
| `duration` | member | not tried |  |
| `endPosition` | member | not tried |  |
| `id` | property | not tried | As on the base event; not tried on this kind. |
| `position` | member | not tried |  |
| `propertyTable` | property | not tried | As on the base event; not tried on this kind. |
| `tonalityDivisionElementID` | member | not tried |  |

## `DoCore.DynamicGroupEvent`

| Member | Kind | Status | Notes |
| ------ | ---- | ------ | ----- |
| `__eq` | operator | not tried |  |
| `__len` | operator | not tried |  |
| `__tostring` | operator | not tried | As on the base event; not tried on this kind. |
| `duration` | member | not tried |  |
| `endPosition` | member | not tried |  |
| `id` | property | not tried | As on the base event; not tried on this kind. |
| `position` | member | not tried |  |
| `propertyTable` | property | not tried | As on the base event; not tried on this kind. |
