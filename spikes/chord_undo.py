"""How many Edit > Undo presses take back the chord symbols recipe? Runs it on a scratch copy of the sample, then
sends Edit.Undo up to fourteen times through the Remote API, listing the chord symbols after each. The copy is closed
unsaved.

    python spikes/chord_undo.py
"""
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tests" / "dorico"))
import harness  # noqa: E402

RUN = {"example": "examples/recipes/chord-symbols.lua", "check": "tests/dorico/checks/chord-symbols.lua"}
COUNT = {"check": "spikes/chord_count_check.lua", "expectScratch": {"path": harness.run_lua.fwd(harness.SCRATCH)}}


def main():
    client = harness.dws.DoricoClient()
    client.connect()
    code, result, sid = harness.run_lua.run(harness.HERE / "case_example.lua", open_file=harness.SAMPLE,
                                            keep_open=True, client=client, extra_args=RUN)
    verified = bool(result and result["facts"].get("scratchVerified"))
    try:
        if not verified:
            print("not verified", code, result)
            return 2
        print("after the run:", result["facts"].get("printed"))
        for i in range(1, 15):
            client.command("Edit.Undo")
            time.sleep(1)
            _, r, _ = harness.run_lua.run(harness.HERE / "case_example.lua", on_active=True, client=client,
                                          extra_args=COUNT)
            print(f"after Edit.Undo {i}: [{(r or {}).get('facts', {}).get('chords')}]")
    finally:
        if verified and sid is not None:
            harness.run_lua.close_scratch(client, sid)
        client.close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
