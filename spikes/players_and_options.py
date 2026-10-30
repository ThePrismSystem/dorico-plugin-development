"""Players, layouts and options: what Lua's layout and flow ids are to the Remote API's getoptions, and what one
Edit > Undo takes back after a script adds a player, renames it, takes it out of a flow and adds a flow. Runs
spikes/players_and_options.lua on a scratch copy of the sample, which is closed unsaved.

    python spikes/players_and_options.py
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
sys.path.insert(0, str(ROOT / "tests" / "dorico"))
import harness  # noqa: E402
import run_lua  # noqa: E402

PROBE = ROOT / "spikes" / "players_and_options.lua"
SCRATCH = {"path": run_lua.fwd(run_lua.RUN_DIR / "scratch.dorico")}
LAYOUT_KEYS = ("flowHeadingBehaviour", "flowBreakBehaviour")
FLOW_KEYS = ("barlineOptions.finalBarlineType", "barlineOptions.defaultBarlineType")


def show(label, result):
    facts = dict((result or {}).get("facts") or {})
    for k in ("activeProjectPath", "scratchVerified", "scratchScoreID"):
        facts.pop(k, None)
    print(label, json.dumps({"checks": (result or {}).get("checks"), "error": (result or {}).get("error"),
                             "facts": facts}, ensure_ascii=False, indent=1))
    return facts


def options(client, facts):
    for layout in facts.get("layouts", []):
        got = harness.options(client, "kLayout", "layoutID", layout["id"])
        print("layout", layout["id"], {k: got.get(k) for k in LAYOUT_KEYS})
    for flow in facts.get("flows", []):
        got = harness.options(client, "kNotation", "flowID", flow["id"])
        print("flow", flow["id"], {k: got.get(k) for k in FLOW_KEYS})


def main():
    client = harness.dws.DoricoClient()
    client.connect()
    code, result, sid = run_lua.run(PROBE, open_file=harness.SAMPLE, keep_open=True, client=client,
                                    extra_args={"step": "look"})
    verified = bool(result and result["facts"].get("scratchVerified"))
    try:
        if not verified:
            print("not verified", code, result)
            return 2
        options(client, show("look", result))
        code, result, _ = run_lua.run(PROBE, on_active=True, client=client,
                                      extra_args={"step": "change", "expectScratch": SCRATCH})
        show("change", result)
        client.command("Edit.Undo")
        code, result, _ = run_lua.run(PROBE, on_active=True, client=client,
                                      extra_args={"step": "look", "expectScratch": SCRATCH})
        show("after Edit.Undo", result)
    finally:
        if verified and sid is not None:
            run_lua.close_scratch(client, sid)
        client.close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
