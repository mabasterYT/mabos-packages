#!/usr/bin/env bash
# Puts the packages of this flake into MabOS's cache: builds its "cache" output, keeps the paths
# cache.nixos.org and the cache's release don't have yet, signs them with the key and uploads them
# to the "cache" release of this repository.
#
#   push.sh                  build, export and upload (needs nix and gh)
#   push.sh --export DIR     build and export into DIR only (where nix is)
#   push.sh --upload DIR     upload DIR only (where gh is)
#
# MABOS_CACHE_KEY: the secret key (~/.config/mabos-cache/secret.key; never in the repo).
set -euo pipefail

repo=mabasterYT/mabos-packages
tag=cache
flake="$(realpath "$(dirname "$0")/..")"
key="${MABOS_CACHE_KEY:-$HOME/.config/mabos-cache/secret.key}"

export_cache() {
    local dir=$1 set path name
    [[ -r $key ]] || { echo "No secret key at $key" >&2; exit 1; }
    mkdir -p "$dir"
    set=$(nix build --no-link --print-out-paths "path:$flake#cache")
    # What the release has already (asset names), so only new paths go up
    local have=""
    if command -v gh >/dev/null; then
        have=$(gh release view "$tag" -R "$repo" --json assets --jq '.assets[].name' | grep '\.narinfo$' || true)
    fi
    # Kept: paths the release doesn't have and cache.nixos.org answers 404 for (any other answer
    # stops the push, so a network hiccup never uploads half of nixpkgs)
    local candidates=() paths=()
    while read -r path; do
        [[ $path == "$set" ]] && continue
        name=$(basename "$path"); name=${name%%-*}
        grep -qx "$name.narinfo" <<<"$have" && continue
        candidates+=("$path")
    done < <(nix path-info -r "$set")
    mapfile -t paths < <(printf '%s\n' "${candidates[@]}" | xargs -r -P 16 -I{} sh -c '
        hash=$(basename "$1" | cut -c1-32)
        code=$(curl -s -o /dev/null -w "%{http_code}" --retry 5 --retry-all-errors "https://cache.nixos.org/$hash.narinfo")
        case $code in
            200) ;;
            404) echo "$1" ;;
            *) echo "cache.nixos.org answered $code for $1" >&2; exit 255 ;;
        esac' sh {})
    if ((${#paths[@]} == 0)); then
        echo "Nothing new for the cache"
        return
    fi
    echo "Exporting ${#paths[@]} paths"
    nix copy --to "file://$dir?compression=xz&secret-key=$key" "${paths[@]}"
    # nix copy writes the whole closure; what cache.nixos.org has stays there
    local keep=" " file
    for path in "${paths[@]}"; do
        name=$(basename "$path"); keep+="${name%%-*} "
    done
    for file in "$dir"/*.narinfo; do
        name=$(basename "$file" .narinfo)
        [[ $keep == *" $name "* ]] && continue
        rm -f "$dir/$(sed -n 's/^URL: //p' "$file")" "$file"
    done
    # Release assets have no folders: the archives sit beside their .narinfo
    sed -i 's|^URL: nar/|URL: |' "$dir"/*.narinfo
    mv "$dir"/nar/* "$dir"/
    # Everything else nix copy writes is a folder (nar/, log/, realisations/, build-trace-v2/...),
    # which a release can't hold and Nix doesn't need for substituting
    find "$dir" -mindepth 1 -maxdepth 1 -type d -exec rm -rf {} +
}

upload_cache() {
    local dir=$1
    compgen -G "$dir/*.narinfo" >/dev/null || { echo "Nothing to upload"; return; }
    gh release upload "$tag" -R "$repo" --clobber "$dir"/nix-cache-info "$dir"/*.narinfo "$dir"/*.nar.*
}

case "${1:-}" in
    --export) export_cache "$2" ;;
    --upload) upload_cache "$2" ;;
    "")
        dir=$(mktemp -d)
        trap 'rm -rf "$dir"' EXIT
        export_cache "$dir"
        upload_cache "$dir"
        ;;
    *) echo "Usage: $0 [--export DIR | --upload DIR]" >&2; exit 2 ;;
esac
