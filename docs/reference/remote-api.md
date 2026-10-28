# The Remote Control API

Dorico's Remote Control API lets a program outside Dorico send it commands and read its state over a WebSocket. This
repository's tests use it to open scratch copies, run scripts and read back what Lua can't, such as options. It's
not available to a script inside Dorico. `tools/dws.py` is a client using only the Python standard library.

Turn it on in Dorico's preferences (Remote Control), then connect to `ws://127.0.0.1:4560`. Every message is JSON.

## Messages the tests use

| Message | Fields | What comes back |
| ------- | ------ | --------------- |
| `connect` | `clientName`, `handshakeVersion: "1.0"`, and a saved `sessionToken` if there is one | The first time, Dorico asks the user to allow the client and sends a token: answer `acceptsessiontoken` with it, and keep it. Then a `response` with `code: "kConnected"`. |
| `command` | `command`: a command string, as for `app:doCommand` | A `response` with a `code`. `Script.RunScript` and `Script.RunLastScript` answer before the script has run. |
| `getstatus` | | A `status` message: `activeOpenScoreID`, `hasSelection`, `selectedEventType` (`kNoteEvent`, `kMixed`, `kNone`) and more. |
| `getoptions` | `optionsType` (`kLayout` or `kNotation`), and `layoutID` or `flowID` | An `optionslist` with each option's `path` and `currentValue`. |
| `setoptions` | | Not used: with `flowIDs` it changed flow 0 instead of the flow named. Set options by command from Lua. |
| `getcommands`, `getflows` | | Every command's name; every flow's id and name. |

## Things to know

- Status messages are partial: each is a change to merge into what you have, and Dorico sends them unasked. Read any
  already waiting before trusting the state.
- Lua's ids for flows and layouts are the ids `getoptions` takes.
- Straight after an `Edit.Undo`, `getoptions` can answer `kCommandNotAllowed`, leave an option out, or show a value
  from before the undo, while Dorico finishes. Ask again a moment later.
- Some commands that work from Lua are refused here: a player rename came back `kError`.
- A command sent while a script waits on a dialog runs only once the dialog closes.
