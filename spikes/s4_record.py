"""S4: which commands does Dorico run when items are made through its popovers? On a scratch copy of the sample,
selects the piano's first note, types into the chord symbol, dynamics and text popovers of that window only, and
prints the commands application.log records. The copy is closed unsaved.

    python spikes/s4_record.py
"""
import os
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import dws  # noqa: E402
import fixture_versions  # noqa: E402
import run_lua  # noqa: E402

PRESS = ROOT / "tools" / "press.ps1"
LOG = Path(os.environ["APPDATA"]) / "Steinberg" / "Dorico 6" / "application.log"
WINDOW = "Sample in scratch"
TRIES = [("chord symbol", "+q", "C7"), ("dynamic", "+d", "mf"), ("text", "+x", "hello")]


def press(keys):
    subprocess.run(["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(PRESS), "-Title", WINDOW,
                    "-Keys", keys], capture_output=True, text=True)
    time.sleep(1.5)


def main():
    client = dws.DoricoClient()
    client.connect()
    code, result, sid = run_lua.run(ROOT / "spikes" / "select_note.lua", open_file=fixture_versions.newest("sample.dorico"),
                                    keep_open=True, client=client, extra_args={"player": "Piano", "pos": 0})
    verified = bool(result and result["facts"].get("scratchVerified"))
    print("selected", code, verified, result and result["facts"].get("selected"))
    try:
        if not verified:
            return 2
        for label, opener, text in TRIES:
            # Escape after each popover can leave nothing selected, so the note is selected again each time
            run_lua.run(ROOT / "spikes" / "select_note.lua", on_active=True, client=client,
                        extra_args={"player": "Piano", "pos": 0,
                                    "expectScratch": {"path": run_lua.fwd(run_lua.RUN_DIR / "scratch.dorico")}})
            start = LOG.stat().st_size
            press(opener)
            press(text)
            press("{ENTER}")
            press("{ESC}")
            with LOG.open("rb") as f:
                f.seek(start)
                new = f.read().decode("utf-8", errors="replace")
            commands = [line.split("Executing command: ", 1)[1] for line in new.splitlines() if "Executing command: " in line]
            print(f"{label}:", commands)
    finally:
        if verified and sid is not None:
            run_lua.close_scratch(client, sid)
        client.close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
