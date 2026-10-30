"""Where the fixtures live. Each project sits in a folder named for the Dorico version that saved it
(fixtures/6.2.30/sample.dorico), and fixtures/versions.json lists them all with their file format version and where
they came from."""
import json
import re
import struct
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FIXTURES = ROOT / "fixtures"
VERSION = re.compile(r"^\d+(\.\d+)*$")


def is_version(name: str) -> bool:
    return bool(VERSION.match(name))


def version_key(name: str) -> tuple:
    """"6.2.30" as (6, 2, 30), so 6.10 sorts after 6.9."""
    if not is_version(name):
        raise ValueError(f"not a version: {name!r}")
    return tuple(int(part) for part in name.split("."))


def newest(name: str, root: Path = FIXTURES) -> Path:
    """The copy of name in the newest version folder that has one."""
    folders = sorted((d for d in root.iterdir() if d.is_dir() and is_version(d.name) and (d / name).exists()),
                     key=lambda d: version_key(d.name))
    if not folders:
        raise FileNotFoundError(f"no version folder in {root} holds {name}")
    return folders[-1] / name


def entries() -> list:
    return json.loads((FIXTURES / "versions.json").read_text(encoding="utf-8"))


def saved_by(path: Path) -> str:
    """The Dorico version that last saved the project, from the project info it keeps beside the score."""
    info = zipfile.ZipFile(path).read("supplementary_data/scoreinfo/scoreinfo.xml").decode("utf-8")
    found = re.search(r"<lastSavedVersion>([^<]*)</lastSavedVersion>", info)
    if not found:
        raise ValueError(f"{path} names no lastSavedVersion")
    return found.group(1)


def _cstrings(data: bytes, p: int, n: int):
    out = []
    for _ in range(n):
        end = data.index(b"\0", p)
        out.append(data[p:end].decode("utf-8"))
        p = end + 1
    return out, p


def _varint(data: bytes, p: int):
    value, scale = 0, 1
    while True:
        b = data[p]
        p += 1
        if b < 128:
            return value + b * scale, p
        value += (b - 128) * scale
        scale *= 128


def file_version(path: Path) -> str:
    """The score's fileVersion. In every file seen so far it is the root's first child, so only the first two
    records of score.dtn are read; score.xml is searched instead."""
    archive = zipfile.ZipFile(path)
    names = archive.namelist()
    if "score.dtn" in names:
        data = archive.read("score.dtn")
        nnames = struct.unpack_from("<I", data, 8)[0]
        node_names, p = _cstrings(data, 12, nnames)
        nvalues = struct.unpack_from("<I", data, p)[0]
        values, p = _cstrings(data, p + 4, nvalues)
        p += 4
        found = []
        for _ in range(2):
            tag = data[p]
            name, p = _varint(data, p + 1)
            value, p = _varint(data, p)
            if tag & 2:
                count, p = _varint(data, p)
                for _ in range(count):
                    _, p = _varint(data, p)
            found.append((node_names[name], values[value]))
        if found[1][0] != "fileVersion":
            raise ValueError(f"{path}: the root's first child is {found[1][0]}, not fileVersion")
        return found[1][1]
    if "score.xml" in names:
        with archive.open("score.xml") as f:
            found = re.search(rb"<fileVersion>([^<]*)</fileVersion>", f.read(4096))
        if found:
            return found.group(1).decode("utf-8")
    raise ValueError(f"{path} has no score with a fileVersion")
