"""What Edit > Undo takes back after a script sets a layout option and a notation option. Runs fundamental 10 on a
scratch copy of the sample, then sends Edit.Undo three times through the Remote API, reading both options back
after each. The copy is closed unsaved.

    python spikes/options_undo.py
"""
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tests" / "dorico"))
import harness  # noqa: E402

ARGS = {"example": "examples/fundamentals/10-layout-and-notation-options.lua",
        "check": "tests/dorico/checks/10-layout-and-notation-options.lua"}


def read(client, label):
    layout = harness.options(client, "kLayout", "layoutID", 0)["flowHeadingBehaviour"]
    flow = harness.options(client, "kNotation", "flowID", 0)["barlineOptions.finalBarlineType"]
    print(f"{label}: flowHeadingBehaviour={layout} finalBarlineType={flow}")


def main():
    client = harness.dws.DoricoClient()
    client.connect()
    code, result, sid = harness.run_lua.run(harness.HERE / "case_example.lua", open_file=harness.SAMPLE,
                                            keep_open=True, client=client, extra_args=ARGS)
    verified = bool(result and result["facts"].get("scratchVerified"))
    try:
        if not verified:
            print("not verified", code, result)
            return 2
        read(client, "after the run")
        for i in range(1, 4):
            client.command("Edit.Undo")
            read(client, f"straight after Edit.Undo {i}")
            time.sleep(3)
            read(client, f"3 s after Edit.Undo {i}")
    finally:
        if verified and sid is not None:
            harness.run_lua.close_scratch(client, sid)
        client.close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
