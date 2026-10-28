"""Which object-model edits does Edit > Undo take back? Seven scratch copies of the sample, each closed unsaved:
  1. text A, a command, text B, and Edit.Undo inside the same run;
  2. the same with no undo in the run, then Edit.Undo through the Remote API, as a user would press it;
  3. text C alone, then Edit.Undo through the Remote API;
  4. an edit of the user's own, then a run that undoes and then makes text D, then Edit.Undo from outside;
  5. an edit of the user's own, then text C alone, then Edit.Undo from outside;
  6. an edit of the user's own, then a text made and deleted in one run, then Edit.Undo from outside;
  7. a note's colour set through its property table, then Edit.Undo from outside.
Runs spikes/undo_object_edits.lua.

    python spikes/undo_object_edits.py
"""
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tests" / "dorico"))
import harness  # noqa: E402

PROBE = ROOT / "spikes" / "undo_object_edits.lua"
SCRATCH = {"path": harness.run_lua.fwd(harness.SCRATCH)}


def facts(result):
    f = (result or {}).get("facts") or {}
    return f"texts [{f.get('texts')}], {f.get('flows')} flows, flow 2 is '{f.get('flow2')}', colour '{f.get('colour')}'" + (
        f" ERROR {result.get('error')}" if result and result.get("error") else "")


def copy(client, first, undo_after, user_edit=False):
    code, result, sid = harness.run_lua.run(PROBE, open_file=harness.SAMPLE, keep_open=True, client=client,
                                            extra_args={"step": "user-edit" if user_edit else first})
    verified = bool(result and result["facts"].get("scratchVerified"))
    try:
        if not verified:
            print("not verified", code, result)
            return
        if user_edit:
            print(f"  after the user's edit (a run of its own): {facts(result)}")
            _, result, _ = harness.run_lua.run(PROBE, on_active=True, client=client,
                                               extra_args={"step": first, "expectScratch": SCRATCH})
        print(f"  after the {first} run: {facts(result)}")
        if undo_after:
            client.command("Edit.Undo")
            time.sleep(2)
            _, result, _ = harness.run_lua.run(PROBE, on_active=True, client=client,
                                               extra_args={"step": "report", "expectScratch": SCRATCH})
            print(f"  after Edit.Undo from outside: {facts(result)}")
    finally:
        if verified and sid is not None:
            harness.run_lua.close_scratch(client, sid)


def main():
    client = harness.dws.DoricoClient()
    client.connect()
    try:
        print("1. text A, Project.Flow.New, text B, Edit.Undo in the run")
        copy(client, "mixed-undo", False)
        print("2. text A, Project.Flow.New, text B; Edit.Undo afterwards")
        copy(client, "mixed", True)
        print("3. text C alone; Edit.Undo afterwards")
        copy(client, "text-only", True)
        print("4. the user's edit; then Project.Flow.New, Edit.Undo and text D in one run; Edit.Undo afterwards")
        copy(client, "undo-then-text", True, user_edit=True)
        print("5. the user's edit; then text C alone; Edit.Undo afterwards")
        copy(client, "text-only", True, user_edit=True)
        print("6. the user's edit; then a text made and deleted in one run; Edit.Undo afterwards")
        copy(client, "text-and-delete", True, user_edit=True)
        print("7. a colour set through the property table; Edit.Undo afterwards")
        copy(client, "property", True)
    finally:
        client.close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
