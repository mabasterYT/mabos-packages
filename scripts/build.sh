#!/usr/bin/env bash
# Builds mabos-gtk4 when it is not published yet and publishes the [mabos] pacman repository: the
# packages, their signatures and the signed database go to this repository's "repo" release.
# Runs as root in an archlinux:base-devel container (the GitHub workflow); needs GH_TOKEN,
# GITHUB_REPOSITORY, MABOS_SIGNING_KEY (the armored secret key) and MABOS_KEY_ID. FORCE=1 builds
# even when this version is already published.
set -euo pipefail
cd "$(dirname "$0")/.."

repo=mabos
release=repo

pacman -Syu --noconfirm --needed git github-cli python >/dev/null

# makepkg refuses to run as root
id builder >/dev/null 2>&1 || useradd -m builder
echo "builder ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/builder
chown -R builder: .
git config --global --add safe.directory "$PWD"
as_builder() { sudo -u builder -H "$@"; }

# Follow Arch's packaging: a new GTK release or changed dependencies are committed back
tag=$(as_builder python3 -I scripts/update-gtk4.py)
sums=$(cd mabos-gtk4 && as_builder makepkg -g 2>/dev/null)
python3 -I - "$sums" <<'EOF'
import re, sys
path = "mabos-gtk4/PKGBUILD"
text = open(path).read()
open(path, "w").write(re.sub(r"b2sums=\(.*?\)\n", sys.argv[1] + "\n", text, flags=re.S))
EOF
if ! git diff --quiet -- mabos-gtk4/PKGBUILD; then
    git -c user.name="github-actions[bot]" -c user.email="41898282+github-actions[bot]@users.noreply.github.com" \
        commit -q -m "mabos-gtk4: follow Arch's gtk4 $tag" -- mabos-gtk4/PKGBUILD
    git push -q origin HEAD
fi

pkgver=$(sed -n 's/^pkgver=//p' mabos-gtk4/PKGBUILD)
pkgrel=$(sed -n 's/^pkgrel=//p' mabos-gtk4/PKGBUILD)
package="mabos-gtk4-$pkgver-$pkgrel-x86_64.pkg.tar.zst"

if ! gh release view "$release" >/dev/null 2>&1; then
    gh release create "$release" --title "pacman repository [mabos]" \
        --notes "MabOS's pacman repository: see the README for how to add it. The files here are replaced by every build."
fi
published=$(gh release view "$release" --json assets --jq '.assets[].name')
if grep -qxF "$package" <<<"$published" && [ "${FORCE:-0}" != 1 ]; then
    echo "$package is published already"
    exit 0
fi

# Sign with MabOS's key, kept only in the workflow's secrets
as_builder gpg --batch --import <<<"$MABOS_SIGNING_KEY"
(cd mabos-gtk4 && as_builder makepkg -s --noconfirm --sign --key "$MABOS_KEY_ID")

out=$(as_builder mktemp -d)
for name in "$repo.db.tar.zst" "$repo.db.tar.zst.sig" "$repo.files.tar.zst" "$repo.files.tar.zst.sig"; do
    if grep -qxF "$name" <<<"$published"; then
        gh release download "$release" --pattern "$name" --dir "$out"
    fi
done
chown -R builder: "$out"
cp "mabos-gtk4/$package" "mabos-gtk4/$package.sig" "$out/"
# repo-add drops the entry of an older mabos-gtk4 from the database
as_builder repo-add --sign --key "$MABOS_KEY_ID" "$out/$repo.db.tar.zst" "$out/$package"
# pacman asks for <repo>.db and <repo>.files; release assets cannot be links
for kind in db files; do
    cp --remove-destination "$out/$repo.$kind.tar.zst" "$out/$repo.$kind"
    cp --remove-destination "$out/$repo.$kind.tar.zst.sig" "$out/$repo.$kind.sig"
done
rm -f "$out"/*.old "$out"/*.old.sig

gh release upload "$release" --clobber "$out"/*
# Older mabos-gtk4 packages leave the release
grep -E '^mabos-gtk4-.*\.pkg\.tar\.zst(\.sig)?$' <<<"$published" | grep -vxF -e "$package" -e "$package.sig" |
    while read -r old; do gh release delete-asset "$release" "$old" --yes; done
echo "published $package"
