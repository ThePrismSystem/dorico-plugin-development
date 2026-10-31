"""Fit a page of the scratch copy in Dorico's view and capture it.

    python tools/snap.py OUT.png --score-id ID [--page N] [--title-like "*scratch*"] [--zoom whole|width|PERCENT]

ID is the copy's OpenScoreID, which run_lua.py --keep-open prints. The view commands go to whichever project is
active, so nothing is sent unless that is the copy.
"""
import argparse
import os
import subprocess
import sys
import time
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import dws  # noqa: E402

CAPTURE = Path(__file__).resolve().parent / "capture.ps1"


def snap(out, score_id, page=1, title_like="*scratch*", zoom="whole", client=None):
    own = client is None
    if own:
        client = dws.DoricoClient()
        client.connect()
    try:
        active = client.status().get("activeOpenScoreID")
        if active != score_id:
            raise RuntimeError(f"the active project (OpenScoreID {active}) is not the copy {score_id}; nothing sent")
        client.command("View.ZoomWholePage" if zoom == "whole" else "View.ZoomPageWidth" if zoom == "width"
                       else f"View.Zoom?ZoomPercent={zoom}")
        client.command(f"Edit.GoToPage?Index={page - 1}")
        time.sleep(1.5)
    finally:
        if own:
            client.close()
    proc = subprocess.run(["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(CAPTURE),
                           "-Out", str(out), "-TitleLike", title_like], capture_output=True, text=True)
    if proc.returncode != 0:
        raise RuntimeError(proc.stderr.strip() or proc.stdout.strip())
    return proc.stdout.strip()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("out")
    ap.add_argument("--score-id", type=int, required=True, help="the scratch copy's OpenScoreID")
    ap.add_argument("--page", type=int, default=1)
    ap.add_argument("--title-like", default="*scratch*")
    ap.add_argument("--zoom", default="whole")
    ns = ap.parse_args()
    print(snap(ns.out, ns.score_id, ns.page, ns.title_like, ns.zoom))


if __name__ == "__main__":
    main()
