#!/usr/bin/env python3
"""MulePost packager: builds the Forever install zip.

Run: python3 tools/package.py
Produces MulePost-0.1.0-Forever.zip in the repo root, containing a
single top-level MulePost/ folder with the .toc and Lua files.
"""
import pathlib
import zipfile

VERSION = "0.1.0"
ROOT = pathlib.Path(__file__).resolve().parent.parent
ADDON = ROOT / "MulePost"


def main():
    out = ROOT / f"MulePost-{VERSION}-Forever.zip"
    names = sorted(p.name for p in ADDON.iterdir() if p.is_file())
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
        for name in names:
            z.write(ADDON / name, f"MulePost/{name}")
    print(f"wrote {out} ({out.stat().st_size} bytes, {len(names)} files)")


if __name__ == "__main__":
    main()
