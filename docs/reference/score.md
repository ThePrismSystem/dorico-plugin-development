# The score

The open project.

Members come from `spikes/class_members.lua`'s scan of Lua's registry, sorted by `tools/members.py` into
[members.json](members.json). "Member" in the Kind column means the scan can't tell a property from a method, since
luabind stores both as functions, and nobody has tried it. Status says whether an example or probe has used a member
(verified), found it broken (fails), or left it alone (not tried). Don't try a member on a project you care about:
a bad call can crash Dorico.

## `DoScore.Score`

| Member | Kind | Status | Notes |
| ------ | ---- | ------ | ----- |
| `__init` | constructor | not tried |  |
| `__len` | operator | not tried |  |
| `__tostring` | operator | not tried |  |
| `addEnsemble` | member | not tried |  |
| `addPlayer` | method | verified | `score:addPlayer(instrumentId, false, 1)` adds a player to every flow and returns it ([16-flows-and-players](../../examples/fundamentals/16-flows-and-players.lua)). The id is an `entityID` from Dorico's `instruments.xml`. |
| `flowIDs` | member | not tried |  |
| `flows` | property | verified | A list of the flows, in order ([02-walk-the-score](../../examples/fundamentals/02-walk-the-score.lua)). |
| `instruments` | member | not tried |  |
| `layouts` | property | verified | A list of the layouts ([15-layout-and-notation-options](../../examples/fundamentals/15-layout-and-notation-options.lua)). |
| `libraries` | member | not tried |  |
| `openScoreID` | property | verified | The id the options commands take ([15-layout-and-notation-options](../../examples/fundamentals/15-layout-and-notation-options.lua)). |
| `players` | property | verified | A list of the players, in order ([02-walk-the-score](../../examples/fundamentals/02-walk-the-score.lua)). |
| `title` | property | verified | The project's title ([01-hello](../../examples/fundamentals/01-hello.lua)). |

## `DoCore.ScoreLibraries`

| Member | Kind | Status | Notes |
| ------ | ---- | ------ | ----- |
| `__len` | operator | not tried |  |
| `__tostring` | operator | not tried |  |
| `brushstyles` | member | not tried |  |
| `clefs` | member | not tried |  |
| `ensembles` | member | not tried |  |
| `fontstyles` | member | not tried |  |
| `instruments` | member | not tried |  |
| `ottavaLines` | member | not tried |  |
| `penstyles` | member | not tried |  |
