# The script host

A class with members for working with projects, which no example reaches.

[The reference's index](README.md#reading-the-tables) explains the Kind and Status columns. Don't try a member
marked "not tried" on a project you care about: a bad call can crash Dorico.

## `DoCore.ScriptHost`

| Member | Kind | Status | Notes |
| ------ | ---- | ------ | ----- |
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
