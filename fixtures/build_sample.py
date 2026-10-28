"""Build fixtures/sample.dorico from fixtures/sample_data.py, end to end, in the running Dorico.

    python fixtures/build_sample.py

1. write the MusicXML and expected.json (make_sample_xml.py)
2. import a copy into Dorico and finish it (finish_sample.lua): the trumpet's gap and a second flow
3. save it as fixtures/sample.dorico and close it
4. open a copy of the saved file and check it (verify_sample.lua)
"""
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(HERE.parent / "tools"))
import dws  # noqa: E402
import make_sample_xml  # noqa: E402
import run_lua  # noqa: E402

TARGET = HERE / "sample.dorico"


def report(name, code, result):
    print(f"{name}: exit {code}")
    if result:
        for c in result.get("checks", []):
            print(f"  {'ok  ' if c['ok'] else 'FAIL'} {c['label']} {c.get('detail') or ''}"[:600])
        if result.get("error"):
            print("  error:", result["error"][:2000])


def wait_saved(path: Path, timeout=60):
    """True once path exists and its size has stopped changing."""
    deadline, last = time.time() + timeout, -1
    while time.time() < deadline:
        if path.exists():
            size = path.stat().st_size
            if size == last and size > 0:
                return True
            last = size
        time.sleep(1)
    return False


def main():
    make_sample_xml.main()
    client = dws.DoricoClient()
    client.connect()
    try:
        code, result, scratch = run_lua.run(HERE / "finish_sample.lua", open_file=make_sample_xml.BUILD / "sample.musicxml",
                                            keep_open=True, client=client, timeout=300)
        report("finish_sample", code, result)
        verified = bool(result and (result.get("facts") or {}).get("scratchVerified"))
        if code != 0 or not verified:
            if scratch is not None and verified:
                run_lua.close_scratch(client, scratch)
            return code or 2
        if TARGET.exists():
            TARGET.unlink()  # SaveAs over an existing file would ask to replace it
        client.command(f"File.SaveAs?File={run_lua.fwd(TARGET)}")
        saved = wait_saved(TARGET)
        run_lua.close_scratch(client, scratch)
        if not saved:
            print(f"{TARGET} was not written: Dorico may be showing a dialog")
            return 2
        print(f"saved {TARGET} ({TARGET.stat().st_size} bytes)")
        time.sleep(2)
        code, result, _ = run_lua.run(HERE / "verify_sample.lua", open_file=TARGET, client=client, timeout=300)
        report("verify_sample", code, result)
        return code
    finally:
        client.close()


if __name__ == "__main__":
    sys.exit(main())
