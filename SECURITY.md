# Security

The examples and the reader library run inside Dorico, on the project you have open. None of them connects to the
internet or installs anything, and none saves your project. Outside the project, they only write a few temporary files,
listed below.

## Reporting a vulnerability

Please report it privately. Open the repository's
[Security tab](https://github.com/ThePrismSystem/dorico-plugin-development/security), choose **Report a
vulnerability**, and describe what you found. Please don't open a public issue for it. I'll reply as soon as I can.

## What running an example does

Most examples change the open project. Each one's opening comment lines say what it changes and how to undo it.

The examples that read the whole score have Dorico save a copy of the open project into the temp folder, then read
the copy and delete it. Saving the copy doesn't change the project's own file, its path or its unsaved mark
([probed](https://github.com/ThePrismSystem/handbells-used-chart-dorico-plugin/blob/main/spike/52_save_copy.lua) for
the Handbells Used Chart plug-in), and adds nothing to its undo history. Fundamental 15 has Dorico export
every text in the project as a CSV into the temp folder, then reads the CSV and deletes it.

## Programs they start

Only the form helper starts a program. Five examples use it to ask for options: 17-ask-and-report,
cautionary-accidentals, find-and-replace, note-names and parallel-fifths.

On Windows, the helper writes a PowerShell script for the box into the temp folder and runs it with Windows PowerShell
5.1, which comes with Windows:

```text
powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "<temp>/dorico-form.ps1" -Out "<temp>/dorico-form.txt"
```

- `-NoProfile` skips your PowerShell profile scripts, so nothing of yours runs alongside the box.
- `-ExecutionPolicy Bypass` lets this one PowerShell process run the script. It doesn't change the execution policy for
  your account or your computer. It's needed because Windows' default policy, Restricted, runs no script files at all.
- `-WindowStyle Hidden` hides PowerShell's console window. The box itself is an ordinary window.
- `-File` runs that one script, with the argument that follows it.

The script loads Windows Forms and System.Drawing, shows the box, and writes your answers to `dorico-form.txt`. The
example then deletes both files. Each label, choice and default goes into the script as a single-quoted PowerShell
string, so text from the score can't run as code. A unit test builds a script whose title tries to break out of its
quotes, and checks that PowerShell's parser reads the whole title back as one string.

On a Mac, the helper runs `osascript`, macOS's own script runner, once for each field, with a `display dialog` or
`choose from list` line. This part is written from Apple's documentation and hasn't been run on a Mac.

[`tests/test_calls.py`](tests/test_calls.py) reads every Lua file in `examples/` and `lib/`. It counts the calls that
start a program, read, write or delete a file, load code or use the network, and the counts must match a list kept in
the test, with a reason for each entry. It matches the names those calls go by, which catches ordinary code; code
written on purpose to disguise a call could still get past it.

## Files they read and write

All of these go in the temp folder: `%TEMP%` on Windows, `$TMPDIR` on a Mac.

- `scorereader-copy.dorico`, the saved copy of the open project. It's deleted once it has been read. If it can't be,
  the Script Console says so, and the next run deletes it first.
- `dorico-form.ps1` and `dorico-form.txt`, the form helper's script and your answers, on Windows.
- `layout-and-notation-options.csv`, fundamental 15's export.

In the library, only two files open files: `lib/scorereader/project.lua` reads the `.dorico` file it's given, and
`lib/scorereader/dorico/savedcopy.lua` saves, reads and deletes the copy.

## No network

None of the examples or the library opens a network connection, downloads anything, or contains a web address.
`tests/test_calls.py` fails if any of it names a networking API (PowerShell's web cmdlets, .NET's `System.Net`, a
socket library), `curl` or `wget`, or a web address.

## The development tools

`tools/`, `tests/`, `spikes/` and `fixtures/` are for developing and testing the examples. You don't need them to run
one. They drive Dorico on the developer's own computer:

- They talk to Dorico's Remote Control API on `127.0.0.1:4560`. Dorico asks you to allow the client the first time,
  and the session token is kept in `.dorico-token`, which git ignores.
- The tests run each example on a scratch copy of a fixture, in `%TEMP%\dorico-examples-run`, and close the copy
  unsaved.
- They find, fill in and press things in Dorico's windows through UI Automation and Win32 calls.

## What the repository checks

| Check | What it covers | Where it runs |
|---|---|---|
| Unit tests | the reader, the examples' helper blocks, and the tools | `test` workflow; `python tools/run_tests.py` |
| In-Dorico tests | every example, run in Dorico on a scratch copy | by hand: `python tools/run_tests.py --dorico` |
| `tests/test_calls.py` | every program, file and network call in `examples/` and `lib/` | with the unit tests |
| luacheck | Lua | `lint` workflow; `python tools/lint.py` |
| lua-language-server | types and nil checks in `examples/`, `lib/` and `types/` | `lint` workflow; `python tools/lint.py` |
| PSScriptAnalyzer, with the InjectionHunter rules | PowerShell | `lint` workflow; `python tools/lint.py` |
| ruff, with its security rules | Python | `lint` workflow; `python tools/lint.py` |
| markdownlint and typos | Markdown, and spelling in every text file | `lint` workflow; `python tools/lint.py` |
| actionlint and zizmor | the GitHub Actions workflows, and Dependabot's settings | `lint` workflow; `python tools/lint.py` |
| gitleaks | secrets anywhere in the git history | `lint` workflow; `python tools/lint.py` |
| CodeQL, `security-extended` queries | Python and the workflows | `codeql` workflow on every pull request, every push to `main`, and weekly; `python tools/lint.py --codeql` |
| lychee | links in the Markdown files | `links` workflow, weekly and on pull requests that change Markdown |
| OpenSSF Scorecard | the repository's security practices | `scorecard` workflow, weekly and on every push to `main` |
| Secret scanning with push protection | every push | GitHub |
| Dependabot | alerts for known vulnerabilities, and updates to the actions and development tools | GitHub |

CodeQL, PSScriptAnalyzer, zizmor, gitleaks and Scorecard report to the Security tab's code scanning page. CodeQL can't
read Lua or PowerShell. luacheck, lua-language-server and the call test cover the Lua, and PSScriptAnalyzer the
PowerShell.

## How the repository is protected

- Changes reach `main` only through pull requests whose checks pass, and every commit on `main` must be signed. Force
  pushes to `main` and deleting it are blocked.
- Workflows get a read-only token unless a job needs more, and every action is pinned to a commit. Workflows from
  outside contributors wait for approval before they run.
