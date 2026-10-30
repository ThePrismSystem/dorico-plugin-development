"""Spike W5, a part on screen: runs w5_menu_in_part.lua on a scratch copy of the reading fixture, showing the flute's
part before the menu command and the full score again afterwards.

    python spikes/w5_menu_in_part.py
"""
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parent
sys.path.insert(0, str(REPO / "tools"))
sys.path.insert(0, str(REPO / "fixtures"))
import dws  # noqa: E402
import run_lua  # noqa: E402
from build_reading import show  # noqa: E402

SCRIPT = HERE / "w5_menu_in_part.lua"


def main():
    client = dws.DoricoClient()
    client.connect()
    scratch = None
    try:
        code, found, scratch = run_lua.run(SCRIPT, open_file=REPO / "fixtures" / "6.2.30" / "reading.dorico",
                                           keep_open=True, extra_args={"stage": "find"}, client=client)
        facts = (found or {}).get("facts") or {}
        print(json.dumps(facts, indent=2))
        if code != 0 or not facts.get("scratchVerified"):
            return code or 2
        show(client, scratch, facts["partLayoutId"])
        code, result, _ = run_lua.run(SCRIPT, on_active=True, client=client,
                                      extra_args={"stage": "set", "expectScratch": {"path": facts["path"]},
                                                  "eventId": facts["note"]["eventId"]})
        print(json.dumps((result or {}).get("facts"), indent=2))
        print("checks:", json.dumps((result or {}).get("checks")))
        show(client, scratch, facts["fullScoreId"])
        return code
    finally:
        if scratch is not None:
            run_lua.close_scratch(client, scratch)
        client.close()


if __name__ == "__main__":
    sys.exit(main())
