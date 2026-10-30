# Values

The values the object model takes and returns.

Members come from `spikes/class_members.lua`'s scan of Lua's registry, sorted by `tools/members.py` into
[members.json](members.json). "Member" in the Kind column means the scan can't tell a property from a method, since
luabind stores both as functions, and nobody has tried it. Status says whether an example or probe has used a member
(verified), found it broken (fails), or left it alone (not tried). Don't try a member on a project you care about:
a bad call can crash Dorico.

## `DoCore.RhythmicLength`

| Member | Kind | Status | Notes |
| ------ | ---- | ------ | ----- |
| `__init` | constructor | verified | `RhythmicLength(n)` keeps only the whole part of n; `RhythmicLength(n, d)` is n/d quarter notes ([11-act-on-the-selection](../../examples/fundamentals/11-act-on-the-selection.lua)). |
| `__add` | operator | not tried |  |
| `__div` | operator | not tried |  |
| `__eq` | operator | not tried |  |
| `__le` | operator | not tried |  |
| `__len` | operator | not tried |  |
| `__lt` | operator | not tried |  |
| `__mul` | operator | not tried |  |
| `__sub` | operator | not tried |  |
| `__tostring` | operator | not tried |  |
| `denominator` | member | not tried |  |
| `numerator` | member | not tried |  |

## `DoCore.MIDIPitchWithSpelling`

| Member | Kind | Status | Notes |
| ------ | ---- | ------ | ----- |
| `MiddleC` | static | not tried |  |
| `__init` | constructor | not tried |  |
| `fromString` | static | verified | `fromString("Ab5")`: a sounding spelling, kept exactly. Can crash Dorico on input it can't read, or above MIDI 127 ([14-add-notes-rests-text](../../examples/fundamentals/14-add-notes-rests-text.lua)). |
| `__eq` | operator | not tried |  |
| `__len` | operator | not tried |  |
| `__tostring` | operator | not tried |  |
| `accidentalType` | member | not tried |  |
| `multitonalFraction` | member | not tried |  |
| `noteName` | member | not tried |  |
| `octave` | member | not tried |  |
| `pitch` | member | not tried |  |

## `DoCore.Variant`

| Member | Kind | Status | Notes |
| ------ | ---- | ------ | ----- |
| `__init` | constructor | not tried |  |
| `createBool` | static | not tried |  |
| `createDouble` | static | not tried |  |
| `createInt` | static | not tried |  |
| `createString` | static | verified | `createString(text)`, for `propertyTable:set` (S8). |
| `__eq` | operator | not tried |  |
| `__len` | operator | not tried |  |
| `__tostring` | operator | verified | The value as text, `""` when unset. |
| `toBool` | member | not tried |  |
| `toDouble` | member | not tried |  |
| `toInt` | member | not tried |  |
| `toString` | member | not tried |  |
| `type` | property | verified | -1 for a colour set by command (S8). |
| `valid` | property | verified | false for a colour set by command, which reads as `""` (S8). |

## `DoCore.NoteName`

| Member | Kind | Status | Notes |
| ------ | ---- | ------ | ----- |
| `__init` | constructor | not tried |  |
| `fromString` | static | not tried |  |

## `DoCore.MIDIPitch`

| Member | Kind | Status | Notes |
| ------ | ---- | ------ | ----- |
| `__init` | constructor | not tried |  |
