"""S6, part two: does Script.ShowConsole toggle the Script Console, or only open it? An example that opens the
console on every run would close it on every second run if it toggles. Runs on a scratch copy of the sample, lists
Dorico's windows after each command, and sends it an even number of times so the console ends as it started.

    python spikes/s6_console_toggle.py
"""
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import dws  # noqa: E402
import fixture_versions  # noqa: E402
import run_lua  # noqa: E402


def main():
    client = dws.DoricoClient()
    client.connect()
    code, result, sid = run_lua.run(ROOT / "spikes" / "00_smoke.lua", open_file=fixture_versions.newest("sample.dorico"),
                                    keep_open=True, client=client)
    verified = bool(result and result["facts"].get("scratchVerified"))
    print("smoke", code, "verified", verified)
    try:
        if not verified:
            return 2
        print("before:", run_lua.window_titles())
        for i in range(1, 5):
            client.command("Script.ShowConsole")
            time.sleep(2)
            print(f"after ShowConsole {i}:", run_lua.window_titles())
    finally:
        if verified and sid is not None:
            run_lua.close_scratch(client, sid)
        client.close()
    print("after closing the copy:", run_lua.window_titles())
    return 0


if __name__ == "__main__":
    sys.exit(main())
