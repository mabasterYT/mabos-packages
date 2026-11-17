#!/usr/bin/env python3
"""MabOS's program index: what nixpkgs can install, for Settings › Apps › Programs and
`mabos package`, searched offline on the machine.

  index.py [--previous versions.json.gz] OUT_DIR

Lists nixos-unstable as it is now (nix-env -qa with metadata) and writes into OUT_DIR:
- index.json.gz: {"rev", "narHash", "date", "packages": [[attr, pname, version, description,
  unfree, mainProgram], ...]}: the snapshot a program is installed from, and what it has.
- versions.json.gz: the history for picking another version: {"revs": {rev: {"narHash", "date"}},
  "versions": {attr: [[version, rev], ...]}}, oldest first; --previous is the last one, which this
  run extends with every version that changed. It starts the day the index does.
"""
import gzip
import json
import os
import subprocess
import sys
import time

CHANNEL = "github:NixOS/nixpkgs/nixos-unstable"
CONFIG = "{ allowUnfree = true; allowAliases = false; }"


def snapshot():
    found = json.loads(subprocess.run(["nix", "flake", "prefetch", "--json", CHANNEL],
                                      check=True, capture_output=True, text=True).stdout)
    return found["locked"]["rev"], found["hash"], found["storePath"]


def packages(source):
    listed = subprocess.run(["nix-env", "-f", source, "-qa", "--json", "--meta", "--arg", "config", CONFIG],
                            check=True, capture_output=True, text=True).stdout
    found = []
    for attr, info in json.loads(listed).items():
        meta = info.get("meta", {})
        if meta.get("broken") or meta.get("available") is False or meta.get("insecure"):
            continue
        license = meta.get("license")
        licenses = license if isinstance(license, list) else [license] if license else []
        unfree = any(isinstance(item, dict) and item.get("free") is False for item in licenses)
        description = " ".join(str(meta.get("description") or "").split())[:200]
        found.append([attr, info.get("pname") or "", info.get("version") or "", description, unfree,
                      meta.get("mainProgram") or ""])
    return sorted(found)


def main():
    args = sys.argv[1:]
    previous = None
    if args[:1] == ["--previous"]:
        previous, args = args[1], args[2:]
    out = args[0]
    os.makedirs(out, exist_ok=True)
    rev, nar_hash, source = snapshot()
    date = time.strftime("%Y-%m-%d", time.gmtime())
    found = packages(source)
    with gzip.open(os.path.join(out, "index.json.gz"), "wt") as f:
        json.dump({"rev": rev, "narHash": nar_hash, "date": date, "packages": found}, f, separators=(",", ":"))

    history = {"revs": {}, "versions": {}}
    if previous and os.path.exists(previous):
        with gzip.open(previous, "rt") as f:
            history = json.load(f)
    history["revs"].setdefault(rev, {"narHash": nar_hash, "date": date})
    for attr, _, version, *_ in found:
        known = history["versions"].setdefault(attr, [])
        if not known or known[-1][0] != version:
            known.append([version, rev])
    with gzip.open(os.path.join(out, "versions.json.gz"), "wt") as f:
        json.dump(history, f, separators=(",", ":"))
    print(f"{len(found)} programs from nixos-unstable {rev[:12]} ({date})")


if __name__ == "__main__":
    main()
