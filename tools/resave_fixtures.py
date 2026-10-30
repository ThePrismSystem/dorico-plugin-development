"""Save the fixtures again in a new Dorico version, then run the tests against them.

    python tools/resave_fixtures.py [--dry-run] [--dorico]

When a new Dorico comes out: start it with Remote Control on and run this. It opens each fixture this repository
builds (not the downloaded ones) from the newest version folder as a scratch copy, saves it with app:save into a new
folder named for the running Dorico's version, lists the new files in fixtures/versions.json, does the same for the
copies of Steinberg's examples in the run folder's inputs/shipped, and runs the unit tests (and the in-Dorico suites
with --dorico). It refuses when the running version already has a folder. A failing test then names the version and
the fixture, and docs/file-format.md says how to teach the reader a new format.
"""
import argparse
import json
import shutil
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
sys.path.insert(0, str(HERE))
import fixture_versions  # noqa: E402

BUILT_HERE = "fixtures/"
SAVER = ROOT / "fixtures" / "resave.lua"


def to_resave(entries):
    """This repository's own fixtures in the newest version folder; downloaded projects stay as their version saved
    them."""
    versions = [e["savedBy"] for e in entries if fixture_versions.is_version(e["savedBy"])]
    newest = max(versions, key=fixture_versions.version_key)
    return [e for e in entries if e["savedBy"] == newest and e["source"].startswith(BUILT_HERE)]


def new_entry(path, file_version, saved_by, from_path):
    return {"path": path, "fileVersion": file_version, "savedBy": saved_by,
            "source": f"re-saved from fixtures/{from_path} by tools/resave_fixtures.py", "credit": ""}


def merged(entries, new):
    return sorted(entries + new, key=lambda e: e["path"])


def refusal(version, root=fixture_versions.FIXTURES):
    if (root / version).exists():
        return f"fixtures/{version} already exists: these fixtures were saved by this Dorico version"
    return None


def write_manifest(path, entries):
    path.write_text(json.dumps(entries, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def save_copy(client, run_lua, source, out):
    """Open a scratch copy of source, save it to out, close the copy; True when out was written."""
    code, _, _ = run_lua.run(SAVER, open_file=source, extra_args={"out": run_lua.fwd(out)}, client=client,
                             timeout=300)
    return code == 0 and out.exists()


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--dry-run", action="store_true", help="say what would be saved, without Dorico")
    ap.add_argument("--dorico", action="store_true", help="also run the in-Dorico suites afterwards")
    ns = ap.parse_args(argv)
    entries = fixture_versions.entries()
    todo = to_resave(entries)
    print("fixtures to save again:", ", ".join(e["path"] for e in todo))
    if ns.dry_run:
        return 0

    import dws
    import run_lua
    staging = run_lua.RUN_DIR / "resave"
    staging.mkdir(parents=True, exist_ok=True)
    client = dws.DoricoClient()
    client.connect()
    try:
        first = staging / Path(todo[0]["path"]).name
        if not save_copy(client, run_lua, fixture_versions.FIXTURES / todo[0]["path"], first):
            print("Dorico could not save", todo[0]["path"])
            return 2
        version = fixture_versions.saved_by(first)
        why = refusal(version)
        if why:
            print(why)
            return 1
        folder = fixture_versions.FIXTURES / version
        folder.mkdir()
        new = []
        for e in todo:
            name = Path(e["path"]).name
            out = staging / name
            if not out.exists() and not save_copy(client, run_lua, fixture_versions.FIXTURES / e["path"], out):
                print("Dorico could not save", e["path"])
                return 2
            shutil.move(str(out), str(folder / name))
            path = f"{version}/{name}"
            new.append(new_entry(path, fixture_versions.file_version(folder / name), version, e["path"]))
            print("saved", path)
        write_manifest(fixture_versions.FIXTURES / "versions.json", merged(entries, new))

        shipped = run_lua.RUN_DIR / "inputs" / "shipped"
        if shipped.is_dir():
            target = run_lua.RUN_DIR / "inputs" / version
            target.mkdir(parents=True, exist_ok=True)
            for project in sorted(shipped.glob("*.dorico")):
                if save_copy(client, run_lua, project, target / project.name):
                    print("saved", target / project.name)
    finally:
        client.close()

    command = [sys.executable, str(HERE / "run_tests.py")] + (["--dorico"] if ns.dorico else [])
    return subprocess.run(command, cwd=ROOT).returncode


if __name__ == "__main__":
    sys.exit(main())
