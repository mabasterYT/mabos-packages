# mabos-cache

Prebuilt packages of MabOS on NixOS: a Nix binary cache kept as files in the `cache` release
(`nix-cache-info`, a `.narinfo` per package and its `.nar.xz`), signed with MabOS's key. MabOS
machines use it after cache.nixos.org:

```
extra-substituters = https://github.com/mabasterYT/mabos-cache/releases/download/cache
extra-trusted-public-keys = mabos-cache-1:8tNp94HPkSJP6/lZpxfUms/743SFz1TsBPqET0sLuG0=
```

It holds only packages MabOS builds itself that cache.nixos.org lacks, never a machine's system or
settings. `.github/workflows/build.yml` builds them from MabOS's `nix/cache/packages.nix` every few
hours and uploads what is new.
