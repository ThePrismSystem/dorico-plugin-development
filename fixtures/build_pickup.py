"""Build fixtures/<version>/pickup.dorico, a one-beat pickup in 4/4, from fixtures/pickup.musicxml in Dorico.

    python fixtures/build_pickup.py
"""
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(HERE.parent / "tools"))
import build_sample  # noqa: E402
import dws  # noqa: E402
import fixture_versions  # noqa: E402
import run_lua  # noqa: E402

SOURCE = HERE / "pickup.musicxml"
BUILT = HERE / "build" / "pickup.dorico"


def main():
    BUILT.parent.mkdir(exist_ok=True)
    client = dws.DoricoClient()
    client.connect()
    try:
        code, result, scratch = run_lua.run(HERE / "finish_pickup.lua", open_file=SOURCE, keep_open=True,
                                            client=client, timeout=300)
        build_sample.report("finish_pickup", code, result)
        verified = bool(result and (result.get("facts") or {}).get("scratchVerified"))
        if code != 0 or not verified:
            if scratch is not None and verified:
                run_lua.close_scratch(client, scratch)
            return code or 2
        if not build_sample.save_as(client, scratch, BUILT):
            return 2
        target = HERE / fixture_versions.saved_by(BUILT) / "pickup.dorico"
        target.parent.mkdir(exist_ok=True)
        BUILT.replace(target)
        print(f"saved {target} ({target.stat().st_size} bytes); list it in fixtures/versions.json if it is new")
        return 0
    finally:
        client.close()


if __name__ == "__main__":
    sys.exit(main())
