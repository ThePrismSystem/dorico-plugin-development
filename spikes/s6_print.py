"""S6: run spikes/s6_print.lua on a scratch copy of the sample, once with the Script Console closed and once after
Script.ShowConsole, capturing Dorico's windows each time. The pictures go to <run folder>/s6-*.png.

    python spikes/s6_print.py
"""
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import dws  # noqa: E402
import fixture_versions  # noqa: E402
import run_lua  # noqa: E402

CAPTURE = ROOT / "tools" / "capture.ps1"
SCRATCH = run_lua.RUN_DIR / "scratch.dorico"


def capture(name):
    out = run_lua.RUN_DIR / f"{name}.png"
    proc = subprocess.run(["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(CAPTURE),
                           "-Out", str(out), "-All"], capture_output=True, text=True)
    print(proc.stdout.strip())


def main():
    client = dws.DoricoClient()
    client.connect()
    code, result, sid = run_lua.run(ROOT / "spikes" / "s6_print.lua", open_file=fixture_versions.newest("sample.dorico"),
                                    keep_open=True, client=client)
    verified = bool(result and result["facts"].get("scratchVerified"))
    print("first run", code, "verified", verified, result and result["facts"])
    try:
        if not verified:
            return 2
        capture("s6-console-closed")
        client.command("Script.ShowConsole")
        time.sleep(2)
        code, result, _ = run_lua.run(ROOT / "spikes" / "s6_print.lua", on_active=True, client=client,
                                      extra_args={"expectScratch": {"path": run_lua.fwd(SCRATCH)}})
        print("second run", code, result and result["facts"])
        time.sleep(1)
        capture("s6-console-open")
        print("titles:", run_lua.window_titles())
    finally:
        if verified and sid is not None:
            run_lua.close_scratch(client, sid)
        client.close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
