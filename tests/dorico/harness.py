"""Helpers for the in-Dorico suites: open a scratch copy of the sample, run cases on it, look at it through the
Remote API, and answer dialogs."""
import json
import subprocess
import sys
import threading
import time
from contextlib import contextmanager
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / "tools"))
import dws  # noqa: E402
import fixture_versions  # noqa: E402
import run_lua  # noqa: E402

SAMPLE = fixture_versions.newest("sample.dorico")
# The projects an example can run on: the sample, the reading fixture, which has one of each kind of item, the
# fixtures built for single recipes, and Somervell's A Shropshire Lad, a score someone typeset.
PROJECTS = {None: SAMPLE, "reading": fixture_versions.newest("reading.dorico"),
            "parallels": fixture_versions.newest("parallels.dorico"),
            "cautionary": fixture_versions.newest("cautionary.dorico"),
            "texts": fixture_versions.newest("texts.dorico"),
            "pickup": fixture_versions.newest("pickup.dorico"),
            "somervell": fixture_versions.newest("Somervell_Shropshire_Lad.dorico")}
SCRATCH = run_lua.RUN_DIR / "scratch.dorico"
CLICK = ROOT / "tools" / "click.ps1"
PRESS = ROOT / "tools" / "press.ps1"
FILL = ROOT / "tools" / "fill.ps1"
SETFIELD = ROOT / "tools" / "setfield.ps1"


def check(test, result, name):
    test.assertIsNotNone(result, f"{name} wrote no result")
    failed = [c for c in result.get("checks", []) if not c["ok"]]
    test.assertTrue(result.get("ok"), json.dumps({"error": result.get("error"), "failed": failed,
                                                  "facts": result.get("facts")}, indent=1, ensure_ascii=False)[:5000])
    return result


@contextmanager
def scratch(test, case, args=None, open_file=SAMPLE, timeout=600):
    """Open a copy, run the first case on it, keep it open for more, and close it (unsaved) at the end."""
    client = dws.DoricoClient()
    client.connect()
    score_id, result = None, None
    try:
        code, result, score_id = run_lua.run(HERE / case, open_file=open_file, keep_open=True, extra_args=args or {},
                                             timeout=timeout, client=client)
        score_id = ((result or {}).get("facts") or {}).get("scratchScoreID", score_id)
        yield client, check(test, result, case)
    finally:
        if result and ((result.get("facts") or {}).get("scratchVerified")):
            run_lua.close_scratch(client, score_id)
        client.close()


def run_more(test, client, case, args=None, timeout=600, expect_ok=True):
    """Run another case on the copy that is still open (the probe confirms it is the active project)."""
    extra = dict(args or {})
    extra["expectScratch"] = {"path": run_lua.fwd(SCRATCH)}
    code, result, _ = run_lua.run(HERE / case, on_active=True, extra_args=extra, timeout=timeout, client=client)
    return check(test, result, case) if expect_ok else result


def example_args(row):
    """case_example.lua's args for a row, or for a step with no example (then only its check runs)."""
    args = {"check": row["check"], "twice": bool(row.get("twice")), **row.get("args", {})}
    if row.get("example"):
        args["example"] = row["example"]
    return args


def options(client, kind, key, ident, wait=15):
    """Layout or notation options through the Remote API: {path: current value}. Straight after an Edit.Undo, Dorico
    can answer kCommandNotAllowed while it finishes, so that answer is retried for a few seconds."""
    deadline = time.time() + wait
    while True:
        client.send({"message": "getoptions", "optionsType": kind, key: ident})
        while True:
            reply = client.recv()
            if reply.get("message") == "optionslist":
                return {o["path"]: o.get("currentValue") for o in reply["options"]}
            if reply.get("message") == "response" and reply.get("code") != "kOK":
                break
        if reply.get("detail") != "kCommandNotAllowed" or time.time() > deadline:
            raise RuntimeError(f"getoptions {kind} {ident}: {reply}")
        time.sleep(0.5)


def click(window, button):
    proc = subprocess.run(["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(CLICK),
                           "-Window", window, "-Button", button], capture_output=True, text=True)
    return proc.returncode == 0


def press(title, keys):
    proc = subprocess.run(["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(PRESS),
                           "-Title", title, "-Keys", keys], capture_output=True, text=True)
    return proc.returncode == 0


def answer(window, button, text=None, timeout=60):
    """Wait for a window (Dorico's or PowerShell's), type text into its text box if given, and press a button.
    True when the button was pressed."""
    if not run_lua.wait_for(lambda: window in run_lua.open_windows(), timeout):
        return False
    if text is not None:
        proc = subprocess.run(["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(FILL),
                               "-Window", window, "-Text", text], capture_output=True, text=True)
        if proc.returncode != 0:
            return False
    return click(window, button)


def answer_form(window, button, fields=(), timeout=60):
    """Wait for a form helper's box, set fields given as (kind, index, value) with kind "text", "check" or "choice",
    and press a button. True when every field was set and the button was pressed."""
    if not run_lua.wait_for(lambda: window in run_lua.open_windows(), timeout):
        return False
    for kind, index, value in fields:
        value = str(value).lower() if isinstance(value, bool) else str(value)
        proc = subprocess.run(["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(SETFIELD),
                               "-Window", window, "-Kind", kind, "-Index", str(index), "-Value", value],
                              capture_output=True, text=True)
        if proc.returncode != 0:
            return False
    return click(window, button)


def wait_for_window(title, timeout=90):
    deadline = time.time() + timeout
    while time.time() < deadline:
        if title in run_lua.window_titles():
            return True
        time.sleep(0.5)
    return False


class Background:
    """Runs a call on a thread (a case that waits on a dialog) and hands back its result."""

    def __init__(self, fn):
        self.result = None
        self.thread = threading.Thread(target=self._run, args=(fn,))
        self.thread.start()

    def _run(self, fn):
        self.result = fn()

    def join(self, timeout=None):
        self.thread.join(timeout)
        return self.result
