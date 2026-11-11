#!/usr/bin/env python3
"""Makes mabos-gtk4/PKGBUILD from mabos-gtk4/PKGBUILD.in and Arch's gtk4 packaging.

update-gtk4.py [<arch tag>]   default: Arch's newest tag (epoch-pkgver-pkgrel, e.g. 1-4.24.1-1)

Takes the version, epoch and both dependency lists from Arch's PKGBUILD at that tag, so a new GTK
release or a changed dependency in Arch's packaging carries over. The checksums are filled in by
`makepkg -g` afterwards (the build script does it), and the hook files are checked against Arch's.
Prints the tag it used. Fails loudly when Arch's PKGBUILD no longer looks as expected.
"""

import os
import re
import subprocess
import sys
import tempfile

ARCH_GIT = "https://gitlab.archlinux.org/archlinux/packaging/packages/gtk4.git"
HERE = os.path.dirname(os.path.abspath(__file__))
PACKAGE = os.path.join(HERE, "..", "mabos-gtk4")
SHARED = ("gtk4-querymodules.hook", "gtk4-querymodules.script")


def newest_tag():
    out = subprocess.run(["git", "ls-remote", "--tags", "--refs", ARCH_GIT], check=True,
                         capture_output=True, text=True).stdout
    tags = [line.split("refs/tags/")[1] for line in out.splitlines() if "refs/tags/" in line]
    tags = [tag for tag in tags if re.fullmatch(r"\d+-[\d.]+-\d+", tag)]
    if not tags:
        sys.exit("no tags found in Arch's gtk4 packaging")
    return max(tags, key=lambda tag: [int(part) for part in re.split(r"[-.]", tag)])


def field(text, name):
    match = re.search(rf"^{name}=(\S+)$", text, re.M)
    if not match:
        sys.exit(f"Arch's PKGBUILD has no {name}=")
    return match.group(1)


def array(text, name):
    match = re.search(rf"^{name}=\(\n(.*?)\n\)", text, re.M | re.S)
    if not match:
        sys.exit(f"Arch's PKGBUILD has no {name}=( ... ) list")
    items = [line.strip() for line in match.group(1).splitlines() if line.strip()]
    if not items or any(" " in item or item.startswith("#") for item in items):
        sys.exit(f"Arch's {name} list looks different than expected: {items}")
    return items


def main():
    tag = sys.argv[1] if len(sys.argv) > 1 else newest_tag()
    with tempfile.TemporaryDirectory() as work:
        subprocess.run(["git", "clone", "--quiet", "--depth", "1", "--branch", tag, ARCH_GIT, work],
                       check=True, stderr=subprocess.DEVNULL)
        with open(os.path.join(work, "PKGBUILD")) as file:
            arch = file.read()
        for name in SHARED:
            with open(os.path.join(work, name), "rb") as theirs, open(os.path.join(PACKAGE, name), "rb") as ours:
                if theirs.read() != ours.read():
                    sys.exit(f"Arch's {name} changed: look at it and copy it over")

    epoch, pkgver, pkgrel = field(arch, "epoch"), field(arch, "pkgver"), field(arch, "pkgrel")
    if tag != f"{epoch}-{pkgver}-{pkgrel}":
        sys.exit(f"tag {tag} does not match Arch's PKGBUILD ({epoch}-{pkgver}-{pkgrel})")
    # Docs are not built here, so their tools are not needed
    makedepends = [item for item in array(arch, "makedepends") if item not in ("docbook-xsl", "gi-docgen")]

    with open(os.path.join(PACKAGE, "PKGBUILD.in")) as file:
        text = file.read()
    for key, value in {
        "ARCH_TAG": tag, "EPOCH": epoch, "PKGVER": pkgver, "PKGREL": pkgrel,
        "DEPENDS": "\n".join("  " + item for item in array(arch, "depends")),
        "MAKEDEPENDS": "\n".join("  " + item for item in makedepends),
        "B2SUMS": "'SKIP' 'SKIP' 'SKIP' 'SKIP'",
    }.items():
        text = text.replace(f"@{key}@", value)
    if re.search(r"@[A-Z0-9_]+@", text):
        sys.exit("a placeholder was left in PKGBUILD")
    with open(os.path.join(PACKAGE, "PKGBUILD"), "w") as file:
        file.write(text)
    print(tag)


if __name__ == "__main__":
    main()
