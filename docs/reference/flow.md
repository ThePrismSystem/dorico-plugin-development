# Flows

A flow, and the element tables it reaches.

Members come from `spikes/class_members.lua`'s scan of Lua's registry, sorted by `tools/members.py` into
[members.json](members.json). "Member" in the Kind column means the scan can't tell a property from a method, since
luabind stores both as functions, and nobody has tried it. Status says whether an example or probe has used a member
(verified), found it broken (fails), or left it alone (not tried). Don't try a member on a project you care about:
a bad call can crash Dorico.

## `DoCore.Flow`

| Member | Kind | Status | Notes |
| ------ | ---- | ------ | ----- |
| `__eq` | operator | not tried |  |
| `__len` | operator | not tried |  |
| `__tostring` | operator | not tried |  |
| `addPlayer` | method | verified | Adds a player to the flow (the handbells plug-in uses it). |
| `allStreams` | property | verified | Every stream of the flow, of every type (the chord-symbols recipe's check). |
| `elementTables` | property | verified | The flow's bar divisions, dynamics and key signatures (S3). |
| `id` | property | verified | What commands take as `FlowID`; the Remote API's ids too. |
| `instruments` | property | verified | One per voice stream, in the same order: `instruments[i]` owns `voiceStreams[i]` ([02-walk-the-score](../../examples/fundamentals/02-walk-the-score.lua)). |
| `playerStreams` | property | not tried |  |
| `players` | property | verified | The players in the flow ([04-noteheads-and-colours](../../examples/fundamentals/04-noteheads-and-colours.lua)). |
| `removePlayer` | method | verified | Takes a player out of this flow ([16-flows-and-players](../../examples/fundamentals/16-flows-and-players.lua)). |
| `staveStreams` | property | verified | One per staff ([04-noteheads-and-colours](../../examples/fundamentals/04-noteheads-and-colours.lua)). |
| `timebaseStreams` | property | not tried |  |
| `voiceStreams` | property | verified | One per voice ([03-read-notes](../../examples/fundamentals/03-read-notes.lua)). |

## `DoCore.FlowElements`

| Member | Kind | Status | Notes |
| ------ | ---- | ------ | ----- |
| `__len` | operator | not tried |  |
| `__tostring` | operator | not tried |  |
| `barDivisions` | property | verified | A table of bar divisions. Their properties can be read, but `kBarDivisionTimeSignatures` fails with "Invalid conversion" (S3). |
| `dynamics` | property | verified | A table of dynamics; each element's sub-elements have readable properties (S3). |
| `tonalityDivisions` | property | fails | "Trying to use unregistered class" (S3). |

## `DoCore.BarDivisionTable`

| Member | Kind | Status | Notes |
| ------ | ---- | ------ | ----- |
| `__len` | operator | not tried |  |
| `__tostring` | operator | not tried |  |
| `createBarDivisionElement` | method | not tried |  |
| `elements` | property | verified | The bar divisions (S3). |

## `DoCore.DynamicTable`

| Member | Kind | Status | Notes |
| ------ | ---- | ------ | ----- |
| `__len` | operator | not tried |  |
| `__tostring` | operator | not tried |  |
| `createDynamicGroup` | method | not tried |  |
| `elements` | property | verified | The dynamics, as groups (S3). |

## `DoCore.DynamicGroupElement`

| Member | Kind | Status | Notes |
| ------ | ---- | ------ | ----- |
| `__eq` | operator | not tried |  |
| `__len` | operator | not tried |  |
| `__tostring` | operator | not tried |  |
| `createEvent` | member | not tried |  |
| `createImmediateChange` | member | not tried |  |
| `events` | member | not tried |  |
| `id` | member | not tried |  |
| `propertyTable` | member | not tried |  |
| `subElements` | property | verified | Each has `kDynamicImmediateChangeBasicType` and `kDynamicImmediateChangeIsMezzo` (S3). |
