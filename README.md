# mabos-packages

MabOS's own Nix packages: programs MabOS on NixOS needs that nixpkgs lacks or has in another
version, and the binary cache they are built into. (The Arch packages of MabOS's `[mabos]` pacman
repository are in [mabos-packages-arch](https://github.com/mabasterYT/mabos-packages-arch).)

| Package | What |
|---|---|
| `strata` | Strata, MabOS's file manager: the upstream release made to run on NixOS, with its file chooser portal |
| `helium` | Helium, a Chromium-based browser: the upstream AppImage |
| `freshgram` | freshGram, a Telegram fork: the upstream build in an FHS environment (patching the binary breaks it) |
| `millennium` | Millennium, Steam's modding framework, from its own Nix files with the tag's source |

MabOS takes them through `overlays.default` (which also gives `millennium-steam`, the system's
Steam with Millennium) and doesn't override this flake's inputs, so its machines get exactly what the
cache holds.

## The cache

The `cache` release holds a Nix binary cache as files (`nix-cache-info`, a `.narinfo` per package
and its `.nar.xz`), signed with MabOS's key. MabOS machines use it after cache.nixos.org:

```
extra-substituters = https://github.com/mabasterYT/mabos-packages/releases/download/cache
extra-trusted-public-keys = mabos-cache-1:8tNp94HPkSJP6/lZpxfUms/743SFz1TsBPqET0sLuG0=
```

`.github/workflows/build.yml` runs `scripts/push.sh` on every push, every six hours and by hand: it
builds the flake's `cache` output and uploads, signed, only the paths neither cache.nixos.org nor
the release has. It holds packages only, never a machine's system or settings. The secret key is the
repository secret `MABOS_CACHE_KEY`.
