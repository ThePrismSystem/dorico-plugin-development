"""Build fixtures/<version>/sample.dorico from fixtures/sample_data.py, end to end, in the running Dorico.

    python fixtures/build_sample.py

1. write the MusicXML and expected.json (make_sample_xml.py)
2. import a copy into Dorico and finish it (finish_sample.lua): the trumpet's gap and a second flow
3. save it, close it, and move it into the folder for the Dorico version that saved it
4. open a copy of the saved file and check it (verify_sample.lua)
"""
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(HERE.parent / "tools"))
import dws  # noqa: E402
import fixture_versions  # noqa: E402
import make_sample_xml  # noqa: E402
import run_lua  # noqa: E402

BUILT = HERE / "build" / "sample.dorico"


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


def close_saved(client, scratch, attempts=5):
    """Close the copy, saved under its new name, and confirm it has gone by Dorico's status: its title no longer ends
    " in scratch", so run_lua.close_scratch would find it gone either way. False when the close isn't confirmed."""
    for _ in range(attempts):
        client.command(f"File.CloseProject?OpenScoreID={scratch}&Save=false")
        time.sleep(1)
        status = client.status()
        if not status.get("hasScore") or status.get("activeOpenScoreID") != scratch:
            return True
        time.sleep(2)
    print("the saved copy could not be closed; close it in Dorico")
    return False


def save_as(client, scratch, built: Path):
    """Save the open copy, OpenScoreID scratch, as built and close it. True when built was written and the copy
    closed. File.SaveAs goes to the active project, so nothing is saved unless that is still the copy."""
    if client.status().get("activeOpenScoreID") != scratch:
        print(f"the active project is not the scratch copy (OpenScoreID {scratch}); nothing saved")
        run_lua.close_scratch(client, scratch)
        return False
    if built.exists():
        built.unlink()  # SaveAs over an existing file would ask to replace it
    client.command(f"File.SaveAs?File={run_lua.fwd(built)}")
    saved = wait_saved(built)
    closed = close_saved(client, scratch)
    if not saved:
        print(f"{built} was not written: Dorico may be showing a dialog")
    return saved and closed


def save_and_verify(client, scratch, built: Path, verify: Path):
    """Save the open copy as built, close it, move the file into the folder for the Dorico version that saved it, and
    check a copy of it with verify. Returns verify's exit code and result."""
    if not save_as(client, scratch, built):
        return 2, None
    target = HERE / fixture_versions.saved_by(built) / built.name
    target.parent.mkdir(exist_ok=True)
    built.replace(target)
    print(f"saved {target} ({target.stat().st_size} bytes); list it in fixtures/versions.json if it is new")
    time.sleep(2)
    code, result, _ = run_lua.run(verify, open_file=target, client=client, timeout=300)
    report(verify.stem, code, result)
    return code, result


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
        return save_and_verify(client, scratch, BUILT, HERE / "verify_sample.lua")[0]
    finally:
        client.close()


if __name__ == "__main__":
    sys.exit(main())
