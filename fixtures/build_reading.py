"""Build fixtures/<version>/reading.dorico from fixtures/make_reading_xml.py, end to end, in the running Dorico.

    python fixtures/build_reading.py

1. write the MusicXML and reading.expected.json (make_reading_xml.py)
2. import a copy into Dorico and finish it (finish_reading.lua): the note properties and a second flow
3. with the flute part on screen, colour the note marked "part" (colour_in_part.lua), then show the full score again
4. save it, close it, and move it into the folder for the Dorico version that saved it
5. open a copy of the saved file and check its notes (verify_reading.lua)
"""
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(HERE.parent / "tools"))
import build_sample  # noqa: E402
import dws  # noqa: E402
import make_reading_xml  # noqa: E402
import run_lua  # noqa: E402

BUILT = HERE / "build" / "reading.dorico"


def show(client, score_id, layout_id):
    view = client.status().get("activeViewContainerID")
    client.command(f"Window.SwitchToLayout?OpenScoreID={score_id}&ScoreLayoutViewContainerID={view}"
                   f"&LayoutID={layout_id}")
    client.settle()


def main():
    make_reading_xml.main()
    client = dws.DoricoClient()
    client.connect()
    try:
        code, result, scratch = run_lua.run(HERE / "finish_reading.lua",
                                            open_file=make_reading_xml.BUILD / "reading.musicxml",
                                            keep_open=True, client=client, timeout=300)
        build_sample.report("finish_reading", code, result)
        verified = bool(result and (result.get("facts") or {}).get("scratchVerified"))
        if code != 0 or not verified:
            if scratch is not None and verified:
                run_lua.close_scratch(client, scratch)
            return code or 2
        print("players:", result["facts"].get("players"))
        for item in result["facts"].get("deferred") or []:
            show(client, scratch, item["layoutId"])
            # The import has no file of its own yet, like any project never saved, so its id goes with it.
            expect = {"expectScratch": {"path": "", "openScoreID": scratch}}
            code, part_result, _ = run_lua.run(HERE / "colour_in_part.lua", on_active=True,
                                               extra_args={**expect, **item}, client=client, timeout=120)
            build_sample.report("colour_in_part", code, part_result)
            show(client, scratch, 0)
            if code != 0:
                run_lua.close_scratch(client, scratch)
                return code
        code, result = build_sample.save_and_verify(client, scratch, BUILT, HERE / "verify_reading.lua")
        if result:
            print("players:", (result.get("facts") or {}).get("players"))
        return code
    finally:
        client.close()


if __name__ == "__main__":
    sys.exit(main())
