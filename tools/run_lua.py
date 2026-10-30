"""Run a Lua script inside Dorico and report the result it writes.

    python tools/run_lua.py SCRIPT [--open FILE] [--keep-open] [--args JSON] [--timeout 120]

The script reports through spikes/lib/probe.lua, which writes %TEMP%/dorico-examples-run/result.json. Dorico runs
it through a launcher written for that one run, which names the run's args file, so a script Dorico gets to late,
after the runner gave up on it, still reads its own args and runId and never a later run's.

With --open, FILE is copied into the run directory and the copy is opened first. The probe checks that the active
project is that copy before doing anything (probe.lua, args.expectScratch), and the runner closes it without saving
afterwards only when the probe confirmed it (unless --keep-open). Without --open the script runs on whatever project
is active, which needs an explicit --on-active.

Exit codes: 0 ok, 1 checks failed, 2 timeout, refusal, connection failure or a copy that can't be seen to close, 3 bad
--args or an error in the runner itself.
"""
import argparse
import json
import os
import shutil
import subprocess
import sys
import time
import traceback
import uuid
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import dws  # noqa: E402



def run_dir_for(env):
    """<temp>/dorico-examples-run, finding the temp folder as spikes/lib/rundir.lua does (the launcher tells the Lua
    side anyway)."""
    temp = env.get("TEMP") or env.get("TMP") or env.get("TMPDIR") or "/tmp"  # noqa: S108 - the folder the Lua side picks
    return Path(temp) / "dorico-examples-run"


RUN_DIR = run_dir_for(os.environ)
REPO = Path(__file__).resolve().parents[1]
PRESS = Path(__file__).resolve().parent / "press.ps1"
CLICK = Path(__file__).resolve().parent / "click.ps1"
TITLES = Path(__file__).resolve().parent / "titles.ps1"
DORICO_PROCESS = "Dorico6"
PROMPT_TIMEOUT = 15  # seconds for one answer, which the 60s open waits on
WINDOW_LIST_TIMEOUT = 30  # seconds for titles.ps1 to list Dorico's windows
# Prompts Dorico raises when opening a scratch copy, and the key that answers each safely.
# Matched by exact window title only; anything else is left alone and the run times out.
KNOWN_PROMPTS = {"Activate Project for Playback": "{ESC}"}  # Esc = "Do Not Activate"
# Prompts answered by clicking their one button. A project an older Dorico saved opens with a notice titled "Dorico"
# whose only button is OK. click.ps1 -OnlyButton presses it only in a window of Dorico's own, and only when it is the
# window's one button, so a "Dorico" prompt that offers a choice, such as one asking to save, is left alone.
KNOWN_BUTTONS = [("Dorico", "OK")]


LUAC_CANDIDATES = ["luac52", "luac5.2", "C:/ProgramData/chocolatey/lib/lua52/tools/luac52.exe", "luac"]


def find_luac():
    """luac 5.2, Dorico's version. A plain "luac" may be 5.3 or 5.4, whose -p accepts code Dorico won't load."""
    for c in LUAC_CANDIDATES:
        found = shutil.which(c) or (c if os.path.isfile(c) else None)
        if not found:
            continue
        try:
            said = subprocess.run([found, "-v"], capture_output=True, text=True, timeout=30)
        except (OSError, subprocess.TimeoutExpired):
            continue
        if (said.stdout + said.stderr).startswith("Lua 5.2"):
            return found
    return None


def lua_files_for(script: Path):
    """The script plus every module it can require: its folder, its lib/, spikes/lib/, fixtures/ and the test
    libraries."""
    script = Path(script).resolve()
    folders = [script.parent, script.parent / "lib", REPO / "spikes" / "lib", REPO / "fixtures",
               REPO / "tests" / "lib", REPO / "tests" / "dorico" / "lib"]
    files, seen = [script], {script}
    listed = [sorted(folder.glob("*.lua")) if folder.is_dir() else [] for folder in folders]
    for group in listed:
        for f in group:
            f = f.resolve()
            if f not in seen:
                seen.add(f)
                files.append(f)
    return files


def syntax_error(script: Path):
    """luac's message for the first file that does not compile, else None.
    Dorico skips a script with a syntax error silently, and a broken module kills it before probe.run."""
    luac = find_luac()
    if not luac:
        return None
    for f in lua_files_for(script):
        proc = subprocess.run([luac, "-p", str(f)], capture_output=True, text=True)
        if proc.returncode != 0:
            return (proc.stderr or proc.stdout).strip()
    return None


class DoricoRefused(Exception):
    """Dorico answered a command with something other than kOK."""


class WindowListError(OSError):
    """titles.ps1 couldn't list Dorico's windows: no Dorico6 process, or the listing failed or took too long."""


def window_titles():
    """The titles of Dorico's visible windows, read through Win32 (titles.ps1), which doesn't wait on a busy Dorico.
    A failed listing raises WindowListError, since an empty list would say no scratch copy is open."""
    try:
        proc = subprocess.run(["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(TITLES),
                               "-Process", DORICO_PROCESS], capture_output=True, text=True, timeout=WINDOW_LIST_TIMEOUT)
    except subprocess.TimeoutExpired:
        raise WindowListError(f"titles.ps1 did not list Dorico's windows within {WINDOW_LIST_TIMEOUT}s") from None
    if proc.returncode != 0:
        said = (proc.stderr or proc.stdout).strip().splitlines()
        raise WindowListError(f"titles.ps1 could not list Dorico's windows: {said[0] if said else proc.returncode}")
    return [line.strip() for line in proc.stdout.splitlines() if line.strip()]


def open_windows(process=None):
    """The titles of the visible windows Dorico and PowerShell (the plug-in's dialog) have open, or only process's,
    read through Win32, which doesn't wait on a busy Dorico as capture.ps1 does. [] off Windows, or if the lookup
    fails."""
    if os.name != "nt":
        return []
    try:
        out = subprocess.run(["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(TITLES)]
                             + (["-Process", process] if process else []),
                             capture_output=True, text=True, timeout=30).stdout
    except (OSError, subprocess.TimeoutExpired):
        return []
    return [line.strip() for line in out.splitlines() if line.strip()]


def answer_known_prompts():
    """Answer the prompts Dorico's own windows show, and say so on stderr: a notice can be about the user's own
    project. Neither script runs unless its window is open, since click.ps1 searches Dorico through UI Automation,
    which can stall for minutes on a busy Dorico."""
    titles = open_windows(DORICO_PROCESS)
    for title, keys in KNOWN_PROMPTS.items():
        if title in titles:
            _answer(PRESS, "-Title", title, "-Keys", keys)
    for title, button in KNOWN_BUTTONS:
        if title in titles:
            _answer(CLICK, "-Window", title, "-Button", button, "-OnlyButton")


def _answer(script, *args):
    try:
        proc = subprocess.run(["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(script), *args],
                              capture_output=True, text=True, timeout=PROMPT_TIMEOUT)
    except subprocess.TimeoutExpired:
        return  # the open polls again until its own limit
    if proc.returncode == 0:
        print(f"answered a Dorico prompt: {proc.stdout.strip()}", file=sys.stderr)


def fwd(path: Path) -> str:
    return str(path.resolve()).replace("\\", "/")


def wait_for(predicate, timeout, interval=0.5):
    deadline = time.time() + timeout
    while time.time() < deadline:
        value = predicate()
        if value:
            return value
        time.sleep(interval)
    return None


def open_scratch(client, source: Path):
    """Open a copy of source; returns (OpenScoreID, scratch path). The id is only a candidate: the probe
    confirms the active project is this copy before anything is changed or closed."""
    before = client.status().get("activeOpenScoreID")
    scratch = RUN_DIR / ("scratch" + source.suffix)
    shutil.copyfile(source, scratch)
    reply = client.command(f"File.Open?File={fwd(scratch)}")
    if reply.get("code") != "kOK":
        raise DoricoRefused(f"Dorico would not open {source.name}: {reply}")

    def opened():
        st = client.status()
        sid = st.get("activeOpenScoreID")
        if st.get("hasScore") and sid is not None and sid != before:
            return (sid,)
        answer_known_prompts()
        return None

    got = wait_for(opened, 60, interval=1)
    if not got:
        raise TimeoutError(f"{source.name} did not open within 60s; Dorico may be showing a dialog")
    # The id appears before Dorico has finished with the project: a script run at once found the text export
    # writing nothing on a large one (Steinberg's Smith example).
    client.settle()
    return got[0], scratch


def scratch_open():
    return any(t.rstrip("*").endswith(" in scratch") for t in window_titles())


def close_scratch(client, score_id: int, attempts=5):
    """Close without saving, and confirm the copy's window has gone: Dorico can ignore a close that arrives
    while it is still finishing the script run. False when the close isn't confirmed."""
    for _ in range(attempts):
        client.command(f"File.CloseProject?OpenScoreID={score_id}&Save=false")
        time.sleep(1)
        try:
            if not scratch_open():
                return True
        except WindowListError as e:
            print(f"{e}; if the scratch copy is still open, close it in Dorico without saving", file=sys.stderr)
            return False
        time.sleep(2)
    print("the scratch copy could not be closed; close it in Dorico without saving", file=sys.stderr)
    return False


def read_result(run_id, problems=None):
    """This run's result, or None. problems, a list, gets what is wrong with a result.json that is there."""
    path = RUN_DIR / "result.json"
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        return None
    except (OSError, ValueError) as e:
        if problems is not None:
            problems[:] = [f"result.json could not be read: {e}"]
        return None
    if data.get("runId") != run_id:
        if problems is not None:
            problems[:] = [f"result.json is another run's (runId {data.get('runId')})"]
        return None
    return data


def write_launcher(script: Path, args: dict, run_id: str) -> Path:
    """The script Dorico is asked to run: it names this run's args file for the probe (spikes/lib/probe.lua), runs
    the script, and forgets the run again, since Dorico keeps one Lua state for every run."""
    for old in list(RUN_DIR.glob("launch-*.lua")) + list(RUN_DIR.glob("args-*.json")):
        old.unlink(missing_ok=True)  # a late run of an earlier launcher then finds nothing to run
    args_path = RUN_DIR / f"args-{run_id}.json"
    args_path.write_text(json.dumps(args), encoding="utf-8")
    launcher = RUN_DIR / f"launch-{run_id}.lua"
    launcher.write_text(
        "-- Written by tools/run_lua.py for one run.\n"
        f"EXAMPLES_RUN = {{ dir = [==[{fwd(RUN_DIR)}/]==], args = [==[{fwd(args_path)}]==] }}\n"
        f"local ok, err = pcall(function() assert(loadfile([==[{fwd(script)}]==]))() end)\n"
        "EXAMPLES_RUN = nil\n"
        "if not ok then error(err, 0) end\n",
        encoding="utf-8")
    return launcher


def run(script: Path, open_file=None, keep_open=False, extra_args=None, timeout=120, client=None, on_active=False):
    """Run one script; returns (exit_code, result_or_None, scratch_score_id_or_None)."""
    RUN_DIR.mkdir(parents=True, exist_ok=True)
    if not open_file and not on_active:
        print("refusing to run on the active project without --on-active (use --open FILE for a scratch copy)", file=sys.stderr)
        return 2, None, None
    if open_file and scratch_open():
        print("a scratch copy from an earlier run is still open; close it in Dorico without saving first", file=sys.stderr)
        return 2, None, None
    err = syntax_error(script)
    if err:
        print(f"syntax error, not sent to Dorico: {err}", file=sys.stderr)
        return 2, None, None
    run_id = uuid.uuid4().hex
    args = dict(extra_args or {})
    args["runId"] = run_id
    try:
        (RUN_DIR / "result.json").unlink()
    except FileNotFoundError:
        pass

    own_client = client is None
    if own_client:
        client = dws.DoricoClient()
        client.connect()
    scratch_id = None
    try:
        if open_file:
            scratch_id, scratch = open_scratch(client, Path(open_file))
            # A .dorico copy is identified by its path. A MusicXML import has an empty path, as has any project never
            # saved, the user's own included, so the probe also wants the id the copy opened as.
            args["expectScratch"] = {"path": fwd(scratch) if scratch.suffix.lower() == ".dorico" else "",
                                     "openScoreID": scratch_id}
        launcher = write_launcher(Path(script).resolve(), args, run_id)
        reply = client.command(f"Script.RunScript?ScriptPath={fwd(launcher)}&ShowConsole=false")
        result, problems = None, []
        if reply.get("code") != "kOK":
            print(f"Dorico would not run the script: {reply}", file=sys.stderr)
        else:
            result = wait_for(lambda: read_result(run_id, problems), timeout)
            if result is None:
                titles = open_windows()
                seen = "; windows open: " + ", ".join(repr(t) for t in titles) if titles else ""
                print(f"timed out after {timeout}s waiting for result" + "".join("; " + p for p in problems) + seen
                      + "; Dorico may be showing a dialog", file=sys.stderr)
        if result is None:
            if scratch_id is not None:
                print("the scratch copy was not closed; close it in Dorico without saving", file=sys.stderr)
            return 2, None, scratch_id
        facts = result.get("facts") or {}
        verified = bool(facts.get("scratchVerified"))
        # The id seen while opening is a guess; the probe reports the verified copy's own id.
        if scratch_id is not None and verified and isinstance(facts.get("scratchScoreID"), int):
            scratch_id = facts["scratchScoreID"]
        if scratch_id is not None and not verified:
            print("the active project could not be confirmed as the scratch copy; nothing was closed", file=sys.stderr)
            return 2, result, scratch_id
        code = 0 if result.get("ok") else 1
        # a copy left open blocks the next run, which refuses to open another
        if scratch_id is not None and not keep_open and not close_scratch(client, scratch_id):
            code = 2
        return code, result, scratch_id
    finally:
        if own_client:
            client.close()


def main(argv=None):
    ap = argparse.ArgumentParser(description=(__doc__ or "").split("\n")[0])  # python -OO drops docstrings
    ap.add_argument("script")
    ap.add_argument("--open", dest="open_file")
    ap.add_argument("--keep-open", action="store_true")
    ap.add_argument("--on-active", action="store_true", help="run on the active project (no scratch copy)")
    ap.add_argument("--args", default="{}")
    ap.add_argument("--timeout", type=float, default=120)
    ns = ap.parse_args(argv)
    try:
        extra = json.loads(ns.args)
    except ValueError as e:
        print(f"--args is not JSON: {e}", file=sys.stderr)
        return 3
    try:
        code, result, scratch_id = run(Path(ns.script), ns.open_file, ns.keep_open, extra, ns.timeout,
                                       on_active=ns.on_active)
    except (OSError, ConnectionError, TimeoutError, EOFError, DoricoRefused) as e:
        print(f"error: {e}", file=sys.stderr)
        return 2
    except Exception:  # noqa: BLE001 (exit 3, so it isn't mistaken for failed checks, exit 1)
        traceback.print_exc()
        return 3
    if result is not None:
        print(json.dumps(result, indent=1, ensure_ascii=False))
    if scratch_id is not None and ns.keep_open:
        print(f"scratch project left open: OpenScoreID={scratch_id}", file=sys.stderr)
    return code


if __name__ == "__main__":
    sys.exit(main())
