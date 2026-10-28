"""What Edit > Undo takes back after a script sets a layout option and a notation option. Runs fundamental 10 on a
scratch copy of the sample, sends one Edit.Undo through the Remote API, and reads both options every half second for
ten seconds, printing when each comes back. Repeats on a fresh copy each time. Each copy is closed unsaved.

    python spikes/options_undo.py [times]
"""
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tests" / "dorico"))
import harness  # noqa: E402

ARGS = {"example": "examples/fundamentals/10-layout-and-notation-options.lua",
        "check": "tests/dorico/checks/10-layout-and-notation-options.lua"}


def read(client):
    layout = harness.options(client, "kLayout", "layoutID", 0).get("flowHeadingBehaviour")
    flow = harness.options(client, "kNotation", "flowID", 0).get("barlineOptions.finalBarlineType")
    return layout, flow


def once(client):
    code, result, sid = harness.run_lua.run(harness.HERE / "case_example.lua", open_file=harness.SAMPLE,
                                            keep_open=True, client=client, extra_args=ARGS)
    verified = bool(result and result["facts"].get("scratchVerified"))
    try:
        if not verified:
            print("not verified", code, result)
            return
        print("  after the run:", read(client))
        client.command("Edit.Undo")
        start, seen = time.time(), None
        while time.time() - start < 10:
            now = read(client)
            if now != seen:
                print(f"  {time.time() - start:4.1f} s after one Edit.Undo: {now}")
                seen = now
            time.sleep(0.5)
    finally:
        if verified and sid is not None:
            harness.run_lua.close_scratch(client, sid)


def main():
    client = harness.dws.DoricoClient()
    client.connect()
    try:
        for i in range(int(sys.argv[1]) if len(sys.argv) > 1 else 1):
            print(f"copy {i + 1}")
            once(client)
    finally:
        client.close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
