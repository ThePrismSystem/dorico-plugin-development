# The app

The objects a script starts from.

[The reference's index](README.md#reading-the-tables) explains the Kind and Status columns. Don't try a member
marked "not tried" on a project you care about: a bad call can crash Dorico.

## `DoApp.DoApp`

| Member | Kind | Status | Notes |
| ------ | ---- | ------ | ----- |
| `__init` | constructor | verified | `DoApp.DoApp()` gives the app ([01-hello](../../examples/fundamentals/01-hello.lua)). |
| `__len` | operator | not tried |  |
| `__tostring` | operator | not tried |  |
| `currentLayoutID` | property | verified | The id of the layout in view (`spikes/players_and_options.lua`). |
| `currentScore` | property | verified | The open project, nil or an error with none open ([01-hello](../../examples/fundamentals/01-hello.lua)). |
| `doCommand` | method | verified | `app:doCommand(text)` runs a command and returns nothing ([10-commands](../../examples/fundamentals/10-commands.lua)). |
| `open` | method | not tried |  |
| `save` | method | verified | `save(score, path)` writes a copy of the project, unsaved edits included, and returns `true`. The project keeps its file, its path and its unsaved mark ([the handbells plug-in's probe](https://github.com/ThePrismSystem/handbells-used-chart-dorico-plugin/blob/main/spike/52_save_copy.lua)), and its undo history ([04-read-the-saved-copy](../../examples/fundamentals/04-read-the-saved-copy.lua)). |
| `versionString` | property | verified | Such as `6.2.30b6245` ([01-hello](../../examples/fundamentals/01-hello.lua)). |

## `DoUI.DoUI`

| Member | Kind | Status | Notes |
| ------ | ---- | ------ | ----- |
| `__init` | constructor | not tried |  |
| `__len` | operator | not tried |  |
| `__tostring` | operator | not tried |  |
| `showFolderChooser` | method | not tried |  |
