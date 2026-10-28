# The script host

A class with members for working with projects, which no example reaches.

Members come from `spikes/class_members.lua`'s scan of Lua's registry, sorted by `tools/members.py` into
[members.json](members.json). "Member" in the Kind column means the scan can't tell a property from a method, since
luabind stores both as functions, and nobody has tried it. Status says whether an example or probe has used a member
(verified), found it broken (fails), or left it alone (not tried). Don't try a member on a project you care about:
a bad call can crash Dorico.

## `DoCore.ScriptHost`

| Member | Kind | Status | Notes |
| ------ | ---- | ------ | ----- |
| `__init` | constructor | not tried |  |
| `__init` | constructor | not tried |  |
| `__len` | operator | not tried |  |
| `__tostring` | operator | not tried |  |
| `convertFolderOfScores` | member | not tried |  |
| `createNewScore` | member | not tried |  |
| `currentScore` | property | not tried | Not a static member of the class (S5), and how to reach it isn't known. |
| `engine` | member | not tried |  |
| `open` | member | not tried |  |
| `save` | method | not tried |  |
| `showFolderChooser` | method | not tried |  |
