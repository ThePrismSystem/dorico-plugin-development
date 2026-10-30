"""Build fixtures/<version>/reading.dorico from fixtures/make_reading_xml.py, end to end, in the running Dorico.

    python fixtures/build_reading.py

1. write the MusicXML and reading.expected.json (make_reading_xml.py)
2. import a copy into Dorico and finish it (finish_reading.lua): the note properties and a second flow
3. with the flute part on screen, colour the note marked "part" (colour_in_part.lua), then show the full score again
4. save it, close it, and move it into the folder for the Dorico version that saved it
5. open a copy of the saved file and check its notes (verify_reading.lua)
"""
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(HERE.parent / "tools"))
import build_sample  # noqa: E402
import dws  # noqa: E402
import fixture_versions  # noqa: E402
import make_reading_xml  # noqa: E402
import run_lua  # noqa: E402

BUILT = HERE / "build" / "reading.dorico"
IMPORTED = {"expectScratch": {"path": ""}}  # an imported copy has no file of its own yet


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
            code, part_result, _ = run_lua.run(HERE / "colour_in_part.lua", on_active=True,
                                               extra_args={**IMPORTED, **item}, client=client, timeout=120)
            build_sample.report("colour_in_part", code, part_result)
            show(client, scratch, 0)
            if code != 0:
                run_lua.close_scratch(client, scratch)
                return code
        if BUILT.exists():
            BUILT.unlink()  # SaveAs over an existing file would ask to replace it
        client.command(f"File.SaveAs?File={run_lua.fwd(BUILT)}")
        saved = build_sample.wait_saved(BUILT)
        run_lua.close_scratch(client, scratch)
        if not saved:
            print(f"{BUILT} was not written: Dorico may be showing a dialog")
            return 2
        target = HERE / fixture_versions.saved_by(BUILT) / "reading.dorico"
        target.parent.mkdir(exist_ok=True)
        BUILT.replace(target)
        print(f"saved {target} ({target.stat().st_size} bytes); list it in fixtures/versions.json if it is new")
        time.sleep(2)
        code, result, _ = run_lua.run(HERE / "verify_reading.lua", open_file=target, client=client, timeout=300)
        build_sample.report("verify_reading", code, result)
        if result:
            print("players:", (result.get("facts") or {}).get("players"))
        return code
    finally:
        client.close()


if __name__ == "__main__":
    sys.exit(main())
