"""Spike W5, undo: does a property set by EventEdit.ChangeProperty join the script run's one undo step?

    python spikes/w5_undo.py

On a scratch copy of the reading fixture, one run sets a bracket on a violin note by id and creates a text; then one
Edit.Undo arrives through the Remote API, as a user's would; then a read-only run reports what is left.
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import dws  # noqa: E402
import fixture_versions  # noqa: E402
import run_lua  # noqa: E402

PROBE = ROOT / "spikes" / "w5_accidentals.lua"


def main():
    client = dws.DoricoClient()
    client.connect()
    sid = None
    verified = False
    try:
        code, result, sid = run_lua.run(PROBE, open_file=fixture_versions.newest("reading.dorico"), keep_open=True,
                                        extra_args={"stage": "set"}, client=client, timeout=300)
        verified = bool(result and (result.get("facts") or {}).get("scratchVerified"))
        if code != 0 or not verified:
            print("the set run failed", json.dumps(result)[:2000])
            return 2
        before = run_lua.run(PROBE, on_active=True, extra_args={"stage": "read", "expectScratch": {
            "path": run_lua.fwd(run_lua.RUN_DIR / "scratch.dorico")}}, client=client, timeout=300)[1]
        client.command("Edit.Undo")
        client.settle()
        after = run_lua.run(PROBE, on_active=True, extra_args={"stage": "read", "expectScratch": {
            "path": run_lua.fwd(run_lua.RUN_DIR / "scratch.dorico")}}, client=client, timeout=300)[1]
        for name, r in (("before undo", before), ("after one undo", after)):
            facts = (r or {}).get("facts") or {}
            print(name, "texts:", facts.get("texts"), "accidentals:", (facts.get("accidentals") or [None] * 3)[2])
        return 0
    finally:
        if sid is not None and verified:
            run_lua.close_scratch(client, sid)
        client.close()


if __name__ == "__main__":
    sys.exit(main())
