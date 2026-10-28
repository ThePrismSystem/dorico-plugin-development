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
import run_lua  # noqa: E402

SAMPLE = ROOT / "fixtures" / "sample.dorico"
SCRATCH = run_lua.RUN_DIR / "scratch.dorico"
CLICK = ROOT / "tools" / "click.ps1"
PRESS = ROOT / "tools" / "press.ps1"


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


def options(client, kind, key, ident):
    """Layout or notation options through the Remote API: {path: current value}."""
    client.send({"message": "getoptions", "optionsType": kind, key: ident})
    while True:
        reply = client.recv()
        if reply.get("message") == "optionslist":
            return {o["path"]: o.get("currentValue") for o in reply["options"]}
        if reply.get("message") == "response" and reply.get("code") != "kOK":
            raise RuntimeError(f"getoptions {kind} {ident}: {reply}")


def click(window, button):
    proc = subprocess.run(["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(CLICK),
                           "-Window", window, "-Button", button], capture_output=True, text=True)
    return proc.returncode == 0


def press(title, keys):
    proc = subprocess.run(["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(PRESS),
                           "-Title", title, "-Keys", keys], capture_output=True, text=True)
    return proc.returncode == 0


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
