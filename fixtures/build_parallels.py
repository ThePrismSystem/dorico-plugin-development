"""Build fixtures/<version>/parallels.dorico from fixtures/make_parallels_xml.py, end to end, in the running Dorico.

    python fixtures/build_parallels.py

1. write the MusicXML and parallels.expected.json (make_parallels_xml.py)
2. import a copy into Dorico and colour two notes as a user might (finish_parallels.lua)
3. save it, close it, and move it into the folder for the Dorico version that saved it
"""
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(HERE.parent / "tools"))
import build_sample  # noqa: E402
import dws  # noqa: E402
import fixture_versions  # noqa: E402
import make_parallels_xml  # noqa: E402
import run_lua  # noqa: E402

BUILT = HERE / "build" / "parallels.dorico"


def main():
    make_parallels_xml.main()
    client = dws.DoricoClient()
    client.connect()
    try:
        code, result, scratch = run_lua.run(HERE / "finish_parallels.lua",
                                            open_file=make_parallels_xml.BUILD / "parallels.musicxml",
                                            keep_open=True, client=client, timeout=300)
        build_sample.report("finish_parallels", code, result)
        verified = bool(result and (result.get("facts") or {}).get("scratchVerified"))
        if code != 0 or not verified:
            if scratch is not None and verified:
                run_lua.close_scratch(client, scratch)
            return code or 2
        if BUILT.exists():
            BUILT.unlink()  # SaveAs over an existing file would ask to replace it
        client.command(f"File.SaveAs?File={run_lua.fwd(BUILT)}")
        saved = build_sample.wait_saved(BUILT)
        run_lua.close_scratch(client, scratch)
        if not saved:
            print(f"{BUILT} was not written: Dorico may be showing a dialog")
            return 2
        target = HERE / fixture_versions.saved_by(BUILT) / "parallels.dorico"
        target.parent.mkdir(exist_ok=True)
        BUILT.replace(target)
        print(f"saved {target} ({target.stat().st_size} bytes); list it in fixtures/versions.json if it is new")
        return 0
    finally:
        client.close()


if __name__ == "__main__":
    sys.exit(main())
