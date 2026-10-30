"""Run the repository's tests.

    python tools/run_tests.py            unit tests (Python and stock Lua 5.2) and a syntax check of every Lua file
    python tools/run_tests.py --dorico   also the checks inside Dorico (needs Dorico running with Remote Control on)
    python tools/run_tests.py --inputs   also reads the local copies of Steinberg's examples (run folder, inputs/)
"""
import argparse
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import fixture_versions  # noqa: E402
import run_lua  # noqa: E402

# test_*.py directly in these folders; tests/dorico/ holds the in-Dorico suites, which only --dorico runs
PY_TEST_FOLDERS = ["tools", "fixtures", "tests"]
LUA_TESTS = ["tests/run.lua", "spikes/lib/test_json.lua"]
LUA_CANDIDATES = ["lua52", "lua5.2", "C:/ProgramData/chocolatey/lib/lua52/tools/lua52.exe", "lua"]
# Dorico skips a script with a syntax error without a word, so every Lua file in these folders is checked
SYNTAX_FOLDERS = ["examples", "lib", "spikes", "tests", "fixtures", "types"]
SAMPLE = fixture_versions.newest("sample.dorico")


def lua_version(exe):
    """The interpreter's _VERSION, such as "Lua 5.2", or None if it won't run."""
    try:
        return subprocess.run([exe, "-e", "io.write(_VERSION)"], capture_output=True, text=True,
                              timeout=30).stdout.strip() or None
    except (OSError, subprocess.TimeoutExpired):
        return None


def find_lua():
    """Lua 5.2, Dorico's version. A plain "lua" may be 5.3 or 5.4, whose integers and libraries differ."""
    import shutil
    import os
    for c in LUA_CANDIDATES:
        found = shutil.which(c) or (c if os.path.isfile(c) else None)
        if found and lua_version(found) == "Lua 5.2":
            return found
    return None


def lua_files(root=ROOT):
    """Every .lua file under the syntax-checked folders of root."""
    files = []
    for folder in SYNTAX_FOLDERS:
        base = Path(root) / folder
        if base.is_dir():
            files.extend(sorted(base.rglob("*.lua")))
    return files


def syntax_errors(files, luac):
    """[(path, message)] for each file luac -p refuses."""
    failures = []
    for path in files:
        proc = subprocess.run([luac, "-p", str(path)], capture_output=True, text=True)
        if proc.returncode != 0:
            failures.append((path, (proc.stderr or proc.stdout).strip()))
    return failures


def py_tests():
    found = []
    for folder in PY_TEST_FOLDERS:
        found.extend(sorted(str(p.relative_to(ROOT)) for p in (ROOT / folder).glob("test_*.py")))
    return found


def step(name, ok):
    print(f"{'PASS' if ok else 'FAIL'}  {name}")
    return ok


def dorico_checks():
    ok = True
    code, _, _ = run_lua.run(ROOT / "spikes" / "00_smoke.lua", on_active=True)  # read-only
    ok &= step("dorico: smoke", code == 0)
    verify = ROOT / "fixtures" / "verify_sample.lua"
    if verify.exists() and SAMPLE.exists():
        code, result, _ = run_lua.run(verify, open_file=SAMPLE, timeout=300)
        if result and code != 0:
            for c in result.get("checks", []):
                if not c["ok"]:
                    print("      ", c["label"], c.get("detail"))
        ok &= step("dorico: the sample project verifies", code == 0)
    for suite in sorted((ROOT / "tests" / "dorico").glob("test_*.py")):
        proc = subprocess.run([sys.executable, str(suite)], cwd=ROOT, capture_output=True, text=True)
        last = proc.stderr.strip().splitlines()[-1] if proc.stderr.strip() else ""
        ok &= step(f"dorico: {suite.name} ({last})", proc.returncode == 0)
        if proc.returncode != 0:
            # the first failure is usually the cause, and later ones its knock-on effects
            first = proc.stderr.find("\n=====")
            print(proc.stderr[max(first, 0):max(first, 0) + 3000])
            print("...")
            print(proc.stderr[-1500:])
    return ok


def input_checks(lua):
    """The reader on every project in the run folder's inputs/ subfolders: Steinberg's examples, as shipped and as
    re-saved, which can't be committed."""
    if not lua:
        return step("inputs: skipped, no stock Lua 5.2 to read them", True)  # its own step has failed already
    projects = sorted(str(p) for p in (run_lua.RUN_DIR / "inputs").glob("*/*.dorico"))
    if not projects:
        return step("inputs: none in " + str(run_lua.RUN_DIR / "inputs"), False)  # --inputs asked for them
    proc = subprocess.run([lua, "tests/inputs.lua", *projects], cwd=ROOT, capture_output=True, text=True)
    print(proc.stdout.rstrip())
    return step(f"inputs: {len(projects)} projects read", proc.returncode == 0)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dorico", action="store_true")
    ap.add_argument("--inputs", action="store_true")
    ns = ap.parse_args()
    ok = True
    proc = subprocess.run([sys.executable, "-m", "unittest", *py_tests()], cwd=ROOT, capture_output=True, text=True)
    ok &= step(f"python unit tests ({proc.stderr.strip().splitlines()[-1] if proc.stderr.strip() else ''})",
               proc.returncode == 0)
    if proc.returncode != 0:
        print(proc.stderr[-3000:])
    lua = find_lua()
    if not lua:
        ok &= step("stock Lua 5.2 found", False)
    else:
        for t in LUA_TESTS:
            proc = subprocess.run([lua, t], cwd=ROOT, capture_output=True, text=True)
            ok &= step(f"lua {t}", proc.returncode == 0)
            if proc.returncode != 0:
                print(proc.stdout[-2000:], proc.stderr[-2000:])
    luac = run_lua.find_luac()
    if not luac:
        ok &= step("luac 5.2 found", False)
    else:
        files = lua_files()
        failures = syntax_errors(files, luac)
        ok &= step(f"luac -p on {len(files)} Lua files", not failures)
        for _, message in failures:
            print("      ", message)
    if ns.inputs:
        ok &= input_checks(lua)
    if ns.dorico:
        ok &= dorico_checks()
    print("ALL PASS" if ok else "SOME FAILED")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
