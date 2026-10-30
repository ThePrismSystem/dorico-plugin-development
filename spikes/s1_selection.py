"""S1: can a script find out what is selected? On a scratch copy of the sample, makes a selection (one note, then
two, then nothing), records the Remote API status for each, and runs spikes/s1_read_selection.lua to name the
selected notes. The copy is closed unsaved.

    python spikes/s1_selection.py
"""
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import dws  # noqa: E402
import fixture_versions  # noqa: E402
import run_lua  # noqa: E402

SCRATCH = {"path": run_lua.fwd(run_lua.RUN_DIR / "scratch.dorico")}


def status(client):
    st = client.status()
    return {k: st.get(k) for k in ("hasSelection", "selectedEventType")}


def read(client, label):
    time.sleep(0.5)
    print(label, "status", status(client))
    code, result, _ = run_lua.run(ROOT / "spikes" / "s1_read_selection.lua", on_active=True, client=client,
                                  extra_args={"expectScratch": SCRATCH})
    facts = (result or {}).get("facts", {})
    print("   ", code, "selected:", facts.get("selected"), "checks:", [(c["label"], c["ok"]) for c in (result or {}).get("checks", [])])


def main():
    client = dws.DoricoClient()
    client.connect()
    code, result, sid = run_lua.run(ROOT / "spikes" / "select_note.lua", open_file=fixture_versions.newest("sample.dorico"),
                                    keep_open=True, client=client,
                                    extra_args={"player": "Violin, solo & tutti", "pos": 0})
    verified = bool(result and result["facts"].get("scratchVerified"))
    print("first selection", code, verified, result and result["facts"].get("selected"))
    try:
        if not verified:
            return 2
        read(client, "one violin note:")
        run_lua.run(ROOT / "spikes" / "select_note.lua", on_active=True, client=client,
                    extra_args={"player": "Violin, solo & tutti", "pos": 0, "expectScratch": SCRATCH})
        client.command("EventEdit.NavigateRightExtend")
        read(client, "two violin notes:")
        client.command("Edit.SelectNone")
        read(client, "nothing:")
    finally:
        if verified and sid is not None:
            run_lua.close_scratch(client, sid)
        client.close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
