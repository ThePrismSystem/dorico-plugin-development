"""Save the fixtures again in a new Dorico version, then run the tests against them.

    python tools/resave_fixtures.py [--dry-run] [--dorico]

When a new Dorico comes out: start it with Remote Control on and run this. It opens each fixture this repository
builds (not the downloaded ones) from the newest version that has them as a scratch copy and saves it with app:save
into a staging folder. Only when every one has saved does it move them into a folder named for the running Dorico's
version and list them in fixtures/versions.json, so a failed run keeps nothing and can be run again. Then it saves the
copies of Steinberg's examples in the run folder's inputs/shipped into inputs/<version>, and runs the unit tests (and
the in-Dorico suites with --dorico). It refuses a version that versions.json already lists this repository's
fixtures for. A failing test then names the version and the fixture, and docs/file-format.md says how to teach the
reader a new format.
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


def own(entries):
    """The entries for fixtures this repository builds. A re-saved copy keeps its builder as its source."""
    return [e for e in entries if e["source"].startswith(BUILT_HERE)]


def to_resave(entries):
    """This repository's own fixtures in the newest version that has them; downloaded projects stay as their version
    saved them."""
    mine = own(entries)
    versions = [e["savedBy"] for e in mine if fixture_versions.is_version(e["savedBy"])]
    newest = max(versions, key=fixture_versions.version_key)
    return [e for e in mine if e["savedBy"] == newest]


def new_entry(path, file_version, saved_by, built):
    """The entry for a copy of built that saved_by saved: built's source and credit, and the copy it came from."""
    return {"path": path, "fileVersion": file_version, "savedBy": saved_by, "source": built["source"],
            "resavedFrom": built["path"], "credit": built["credit"]}


def merged(entries, new):
    return sorted(entries + new, key=lambda e: e["path"])


def refusal(version, entries, names, root):
    """Why the files named can't go into root/version, or None. A folder holding only downloaded projects takes
    them."""
    if any(e["savedBy"] == version for e in own(entries)):
        return f"versions.json already lists fixtures saved by {version}"
    there = [name for name in names if (root / version / name).exists()]
    if there:
        return f"fixtures/{version} already holds {', '.join(there)}"
    return None


def write_manifest(path, entries):
    path.write_text(json.dumps(entries, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def install(staged, version, entries, root):
    """Move the staged copies, [(built entry, file, fileVersion)], into root/version and list them in versions.json.
    On any failure it takes back what it moved, and the folder too if it made it."""
    folder = root / version
    made = not folder.exists()
    folder.mkdir(exist_ok=True)
    moved, new = [], []
    try:
        for built, out, file_version in staged:
            target = folder / out.name
            moved.append(target)
            shutil.move(str(out), str(target))
            new.append(new_entry(f"{version}/{out.name}", file_version, version, built))
        write_manifest(root / "versions.json", merged(entries, new))
    except BaseException:
        if made:
            shutil.rmtree(folder, ignore_errors=True)
        else:
            for target in moved:
                target.unlink(missing_ok=True)
        raise
    return new


def save_copy(client, run_lua, source, out):
    """Open a scratch copy of source, save it to out, close the copy; True when out was written. When the save
    fails nothing is left at out."""
    try:
        code, _, _ = run_lua.run(SAVER, open_file=source, extra_args={"out": run_lua.fwd(out)}, client=client,
                                 timeout=300)
    except TimeoutError as e:
        print(e)
        code = None
    if code == 0 and out.exists():
        return True
    out.unlink(missing_ok=True)
    return False


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--dry-run", action="store_true", help="say what would be saved, without Dorico")
    ap.add_argument("--dorico", action="store_true", help="also run the in-Dorico suites afterwards")
    ns = ap.parse_args(argv)
    root = fixture_versions.FIXTURES
    entries = fixture_versions.entries()
    todo = to_resave(entries)
    print("fixtures to save again:", ", ".join(e["path"] for e in todo))
    if ns.dry_run:
        return 0

    import dws
    import run_lua
    staging = run_lua.RUN_DIR / "resave"
    shutil.rmtree(staging, ignore_errors=True)  # a file an earlier run left could pass for this run's save
    staging.mkdir(parents=True)
    client = dws.DoricoClient()
    client.connect()
    try:
        staged = []
        for e in todo:
            out = staging / Path(e["path"]).name
            if not save_copy(client, run_lua, root / e["path"], out):
                print("Dorico could not save", e["path"])
                return 2
            staged.append((e, out, fixture_versions.file_version(out)))
        version = fixture_versions.saved_by(staged[0][1])
        why = refusal(version, entries, [out.name for _, out, _ in staged], root)
        if why:
            print(why)
            return 1
        for e in install(staged, version, entries, root):
            print("saved", e["path"])

        failed = []
        shipped = run_lua.RUN_DIR / "inputs" / "shipped"
        if shipped.is_dir():
            target = run_lua.RUN_DIR / "inputs" / version
            target.mkdir(parents=True, exist_ok=True)
            for project in sorted(shipped.glob("*.dorico")):
                if save_copy(client, run_lua, project, target / project.name):
                    print("saved", target / project.name)
                else:
                    print("Dorico could not save", project)
                    failed.append(project.name)
    finally:
        client.close()

    command = [sys.executable, str(HERE / "run_tests.py")] + (["--dorico"] if ns.dorico else [])
    code = subprocess.run(command, cwd=ROOT).returncode
    if failed:
        print("examples not saved again:", ", ".join(failed))
    return code or (2 if failed else 0)


if __name__ == "__main__":
    sys.exit(main())
