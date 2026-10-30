"""Every program, file and code-loading call the examples and the reader library make, and that none uses the network.

    python -m unittest tests/test_calls.py
"""
import re
import subprocess
import unittest
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

# The programs the form helper starts, as its code spells them. SECURITY.md describes each one.
PROCESSES = [
    "powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File",
    "osascript",
]

# The form helper, a "-- helper: form" block that five examples carry.
FORM = {
    "os.execute": 1,  # on Windows, powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File on the box
    "io.popen": 1,  # on a Mac, osascript, once for each field, reading its answer
    "io.open": 2,  # writes the box's script into the temp folder, and reads the answer it writes
    "os.remove": 3,  # the last answer before the box opens, then the script and the answer once it has been read
    "os.getenv": 2,  # TEMP or TMP: the temp folder
}

# What each file may call, and why. Anything not listed here must not appear.
ALLOWED = {
    "examples/fundamentals/15-layout-and-notation-options.lua": {
        "command File.Export.Text": 1,  # Dorico exports the project's options to a CSV in the temp folder
        "os.getenv": 3,  # TEMP, TMPDIR or TMP: the temp folder
        "os.remove": 2,  # the CSV, before the export and once it has been read
        "io.open": 1,  # reads the CSV
    },
    "examples/fundamentals/17-ask-and-report.lua": FORM,
    "examples/recipes/cautionary-accidentals.lua": FORM,
    "examples/recipes/find-and-replace.lua": FORM,
    "examples/recipes/note-names.lua": FORM,
    "examples/recipes/parallel-fifths.lua": FORM,
    "lib/scorereader/dorico/savedcopy.lua": {
        "DoApp:save": 1,  # app:save writes a copy of the open project into the temp folder
        "io.open": 1,  # reads the copy
        "os.remove": 1,  # deletes the copy, before the save and once it has been read
        "os.getenv": 2,  # TEMP or TMPDIR: the temp folder
    },
    "lib/scorereader/project.lua": {
        "io.open": 1,  # reads the .dorico file it is given
    },
}

LUA_CALLS = [
    ("os.execute", r"\bos\.execute\b"), ("io.popen", r"\bio\.popen\b"), ("io.open", r"\bio\.open\b"),
    ("io.lines", r"\bio\.lines\b"), ("os.remove", r"\bos\.remove\b"), ("os.rename", r"\bos\.rename\b"),
    ("os.tmpname", r"\bos\.tmpname\b"), ("os.getenv", r"\bos\.getenv\b"), ("load", r"(?<![\w.:])load\s*\("),
    ("io.output", r"\bio\.output\b"), ("io.input", r"\bio\.input\b"), ("io.tmpfile", r"\bio\.tmpfile\b"),
    ("loadstring", r"\bloadstring\b"), ("loadfile", r"\bloadfile\b"), ("dofile", r"\bdofile\b"),
    ("package.loadlib", r"\bpackage\.loadlib\b"),
    # Dorico's own app:save(score, path), which writes a project file
    ("DoApp:save", r":save\s*\("),
]
NETWORK_CALLS = [
    ("Invoke-WebRequest", r"(?i)\bInvoke-WebRequest\b|(?<![\w$-])iwr\b"),
    ("Invoke-RestMethod", r"(?i)\bInvoke-RestMethod\b|(?<![\w$-])irm\b"),
    ("System.Net", r"(?i)\b(?:System\.)?Net\.[A-Za-z]\w*"), ("Start-BitsTransfer", r"(?i)\bStart-BitsTransfer\b"),
    ("URL", r"(?i)\b(?:https?|ftp)://"), ("socket", r"(?i)\bsocket\b"), ("curl/wget", r"(?i)\b(?:curl|wget)\b"),
]
NETWORK = [name for name, _ in NETWORK_CALLS]

LUA_LONG = re.compile(r"\[(=*)\[")


def blank(text):
    """A removed comment: a space, so the tokens either side stay apart, and its newlines, so lines keep their numbers."""
    return " " + "\n" * text.count("\n")


def string_end(src, i):
    """Where the quoted string that opens at src[i] ends. An unterminated one ends at the line's end (or the file's)."""
    quote, j = src[i], i + 1
    while j < len(src):
        ch = src[j]
        if ch == "\\":
            j += 2
            continue
        if ch == quote:
            return j + 1
        if ch == "\n":
            return j
        j += 1
    return len(src)


def strip_comments(src, keep_strings=True):
    """The code without its comments. keep_strings=False also empties every string, keeping its newlines."""
    def string(text):
        return text if keep_strings else '""' + "\n" * text.count("\n")
    out, i = [], 0
    while i < len(src):
        if src.startswith("--", i):
            long = LUA_LONG.match(src, i + 2)
            if long:
                close = src.find("]" + long.group(1) + "]", long.end())
                end = len(src) if close < 0 else close + len(long.group(1)) + 2
            else:
                end = src.find("\n", i)
                end = len(src) if end < 0 else end
            out.append(blank(src[i:end]))
        elif opener := LUA_LONG.match(src, i):
            close = src.find("]" + opener.group(1) + "]", opener.end())
            end = len(src) if close < 0 else close + len(opener.group(1)) + 2
            out.append(string(src[i:end]))
        elif src[i] in "\"'":
            end = string_end(src, i)
            out.append(string(src[i:end]))
        else:
            end = i + 1
            out.append(src[i])
        i = end
    return "".join(out)


def calls(src):
    """{call: how many times the code (comments left out) names it}."""
    src = src.replace("\r\n", "\n")  # as git stores it, whichever way the file was checked out
    code = strip_comments(src)
    found = Counter()
    for name, pattern in LUA_CALLS + NETWORK_CALLS:
        found[name] += len(re.findall(pattern, code))
    named = re.findall(r"\brequire\s*[(,]?\s*[\"']([^\"']+)[\"']", code)  # require("x"), pcall(require, "x")
    found.update("require " + m for m in named if m != "scorereader" and not m.startswith("scorereader."))
    found["require (not a literal name)"] += len(re.findall(r"\brequire\b", code)) - len(named)
    # Dorico's commands that write or run files, such as File.Export.Text
    found.update("command " + c for c in re.findall(r"[\"']((?:File|Script)\.[A-Za-z.]+)[\"']", code))
    # os, io, package and debug only as os.execute and the like, so every use is one of the names above
    bare = strip_comments(src, keep_strings=False)
    for lib in ("os", "io", "package", "debug"):
        found[lib + " as a value"] += len(re.findall(r"(?<![\w.:])" + lib + r"\b(?!\s*\.)", bare))
    return +found


def checked_files():
    """The tracked Lua files in examples/ and lib/: what a user copies into Dorico."""
    out = subprocess.run(["git", "ls-files", "-z", "--", "examples", "lib"], cwd=ROOT, capture_output=True,
                         check=True).stdout.decode("utf-8")
    return sorted(p for p in out.split("\0") if p.endswith(".lua"))


def found_calls():
    return [(path, calls((ROOT / path).read_text(encoding="utf-8"))) for path in checked_files()]


class StripTests(unittest.TestCase):
    def test_line_comment_is_not_code(self):
        self.assertEqual(calls('x = 1 -- os.execute("rm")\n'), Counter())

    def test_long_comment_is_not_code(self):
        self.assertEqual(calls("--[==[ os.execute ]==] y()\n"), Counter())

    def test_dashes_in_a_string_are_code(self):
        self.assertEqual(calls('s = "--" os.execute(s)\n')["os.execute"], 1)

    def test_long_string_keeps_what_follows(self):
        self.assertEqual(calls("s = [[--]] os.remove(p)\n")["os.remove"], 1)

    def test_crlf_counts_the_same(self):
        src = 's = "--" os.execute(s) -- os.remove\n'
        self.assertEqual(calls(src.replace("\n", "\r\n")), calls(src))

    def test_newlines_survive(self):
        src = "a()\n--[[\nx\n]]\nb()\n"
        self.assertEqual(strip_comments(src).count("\n"), src.count("\n"))

    def test_package_loaded_is_not_load(self):
        self.assertEqual(calls('package.loaded["x"] = nil\n'), Counter())

    def test_require_through_pcall_is_named(self):
        self.assertEqual(calls('local ok, m = pcall(require, "lfs")\n'), Counter({"require lfs": 1}))

    def test_the_reader_library_is_not_counted(self):
        self.assertEqual(calls('local score = require("scorereader.score")\n'), Counter())

    def test_io_redirection_is_counted(self):
        found = calls('io.output("f") io.input("g") local t = io.tmpfile()\n')
        self.assertEqual(found, Counter({"io.output": 1, "io.input": 1, "io.tmpfile": 1}))

    def test_library_used_as_a_value_is_counted(self):
        self.assertEqual(calls('local x = os; x.execute("y")\n')["os as a value"], 1)
        self.assertEqual(calls('os["execute"]("y")\n')["os as a value"], 1)
        self.assertEqual(calls('package.loaded.x = nil; debug.getinfo(1)\n'), Counter())

    def test_dorico_file_and_script_commands_are_counted(self):
        src = 'app:doCommand(commands.build("File.Export.Text", {})) app:doCommand("Script.Run")\n'
        self.assertEqual(calls(src), Counter({"command File.Export.Text": 1, "command Script.Run": 1}))

    def test_dorico_save_to_a_path_is_counted(self):
        self.assertEqual(calls("local ok = app:save(app.currentScore, path)\n"), Counter({"DoApp:save": 1}))

    def test_urls_in_strings_are_network(self):
        found = calls('local u = "https://example.com"\n')
        self.assertEqual(found, Counter({"URL": 1}))
        self.assertIn("URL", NETWORK)


class CallTests(unittest.TestCase):
    def test_calls_match_the_allow_list(self):
        for path, found in found_calls():
            self.assertEqual(dict(found), ALLOWED.get(path, {}), path)

    def test_allow_list_names_only_checked_files(self):
        self.assertLessEqual(set(ALLOWED), set(checked_files()))

    def test_no_network_calls(self):
        for path, found in found_calls():
            self.assertFalse({name: n for name, n in found.items() if name in NETWORK}, path)

    def test_security_md_names_every_process(self):
        security = (ROOT / "SECURITY.md").read_text(encoding="utf-8")
        for command in PROCESSES:
            self.assertIn(command, security)

    def test_every_process_is_in_the_code(self):
        code = "\n".join(strip_comments((ROOT / path).read_text(encoding="utf-8").replace("\r\n", "\n"))
                         for path in checked_files())
        for command in PROCESSES:
            self.assertIn(command, code)


if __name__ == "__main__":
    unittest.main()
