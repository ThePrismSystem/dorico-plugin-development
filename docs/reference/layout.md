# Layouts

A layout: the full score or a part.

[The reference's index](README.md#reading-the-tables) explains the Kind and Status columns. Don't try a member
marked "not tried" on a project you care about: a bad call can crash Dorico.

## `DoCore.Layout`

| Member | Kind | Status | Notes |
| ------ | ---- | ------ | ----- |
| `__eq` | operator | not tried |  |
| `__len` | operator | not tried |  |
| `__tostring` | operator | not tried |  |
| `addFlow` | member | not tried |  |
| `addPlayer` | method | verified | Adds a player to the layout (the handbells plug-in). |
| `id` | property | verified | What `LayoutIDArray` takes; layout 0 is the full score in a fresh project ([15-layout-and-notation-options](../../examples/fundamentals/15-layout-and-notation-options.lua)). |
| `players` | property | verified | The players in the layout ([15-layout-and-notation-options](../../examples/fundamentals/15-layout-and-notation-options.lua)). |
| `removeFlow` | method | verified | Leaves a flow out of the layout (the handbells plug-in), so an empty flow doesn't print "Tacet". |
| `removePlayer` | member | not tried |  |
