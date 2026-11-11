#!/usr/bin/env bash
# Publishes the [mabos] pacman repository: for every repository in packages.txt, takes the package
# in its "package" release when [mabos] does not have that file yet, signs it with MabOS's key, adds
# it to the database (which drops the older version of that package) and replaces this repository's
# "repo" release files. Only this script writes the database, so packages built at the same time
# cannot overwrite each other's entries. Runs as root in an archlinux:base-devel container (the
# GitHub workflow); needs GH_TOKEN, MABOS_SIGNING_KEY (the armored secret key) and MABOS_KEY_ID.
set -euo pipefail
cd "$(dirname "$0")/.."

repo=mabos
release=repo

pacman -Syu --noconfirm --needed github-cli >/dev/null
gpg --batch --import <<<"$MABOS_SIGNING_KEY"

if ! gh release view "$release" >/dev/null 2>&1; then
    gh release create "$release" --title "pacman repository [mabos]" \
        --notes "MabOS's pacman repository: see the README for how to add it. The files here are replaced by every publish."
fi
published=$(gh release view "$release" --json assets --jq '.assets[].name')

out=$(mktemp -d)
for name in "$repo.db.tar.zst" "$repo.files.tar.zst"; do
    if grep -qxF "$name" <<<"$published"; then
        gh release download "$release" --pattern "$name" --dir "$out"
    fi
done

added=()
while read -r source; do
    source=${source%%#*}
    source=${source//[[:space:]]/}
    [ -n "$source" ] || continue
    name=$(gh release view package -R "$source" --json assets \
        --jq '.assets[].name | select(endswith(".pkg.tar.zst"))' 2>/dev/null | head -n 1 || true)
    if [ -z "$name" ]; then
        echo "$source: no package yet"
        continue
    fi
    if grep -qxF "$name" <<<"$published"; then
        echo "$source: $name is published already"
        continue
    fi
    gh release download package -R "$source" --pattern "$name" --dir "$out"
    gpg --batch --yes --detach-sign --local-user "$MABOS_KEY_ID" --output "$out/$name.sig" "$out/$name"
    repo-add --sign --key "$MABOS_KEY_ID" "$out/$repo.db.tar.zst" "$out/$name"
    added+=("$name")
done < packages.txt

if [ ${#added[@]} -eq 0 ]; then
    echo "nothing new"
    exit 0
fi

# pacman asks for <repo>.db and <repo>.files; release assets cannot be links
for kind in db files; do
    cp --remove-destination "$out/$repo.$kind.tar.zst" "$out/$repo.$kind"
    cp --remove-destination "$out/$repo.$kind.tar.zst.sig" "$out/$repo.$kind.sig"
done
rm -f "$out"/*.old "$out"/*.old.sig
gh release upload "$release" --clobber "$out"/*

# The older version of each new package leaves the release
for name in "${added[@]}"; do
    pkgname=$(bsdtar -xOf "$out/$name" .PKGINFO | sed -n 's/^pkgname = //p')
    { grep -E "^$pkgname-[^-]+-[^-]+-[^-]+\.pkg\.tar\.zst(\.sig)?$" <<<"$published" | grep -vxF -e "$name" -e "$name.sig" || true; } |
        while read -r old; do gh release delete-asset "$release" "$old" --yes; done
    echo "published $name"
done
