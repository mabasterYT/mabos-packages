# MabOS packages

The pacman repository `[mabos]` of [MabOS](https://github.com/mabasterYT), an Arch Linux setup with
niri and Quickshell: Arch packages with small MabOS changes, built here by GitHub Actions and signed
with MabOS's key. Anyone on Arch can use them.

## Packages

### mabos-gtk4

Arch's `gtk4` with one patch: open GTK 4 windows read `~/.config/gtk-4.0/gtk.css` again when it
changes, so switching a theme recolors the apps that are already open instead of only the ones
started afterwards (Nautilus, libadwaita apps, file choosers...). Plain GTK 4 reads that file once,
when an app starts.

- The patch (`mabos-gtk4/mabos-user-css-live-reload.patch`, in `gtk/gtksettings.c`) watches the
  `~/.config/gtk-4.0` folder, so a `gtk.css` written in place, replaced by a rename or removed is
  seen; 150 ms after the last change it loads the file again (an empty style when it is gone).
- Everything else is Arch's: `scripts/update-gtk4.py` makes `mabos-gtk4/PKGBUILD` from
  `PKGBUILD.in` and Arch's packaging every day, so new GTK versions and dependency changes follow
  Arch's `gtk4`. Demos, docs and tests are not built; `gtk-update-icon-cache` stays Arch's.
- It replaces `gtk4` (it provides `gtk4` and `libgtk-4.so`). `pacman -S gtk4` goes back.
- Flatpak apps use their runtime's GTK and are not affected, nor is GTK 3.
- The idea comes from [saneaspect/gtk4-live-css](https://github.com/saneaspect/gtk4-live-css); the
  patch here is MabOS's own.

## Using the repository

Trust MabOS's signing key (fingerprint `2918F1A00FA8F3F9A847904D92D811A9B2583DF6`):

```sh
curl -sL https://raw.githubusercontent.com/mabasterYT/mabos-packages/main/keys/mabos.asc | sudo pacman-key --add -
sudo pacman-key --lsign-key 2918F1A00FA8F3F9A847904D92D811A9B2583DF6
```

Add the repository to `/etc/pacman.conf`, after Arch's own:

```ini
[mabos]
Server = https://github.com/mabasterYT/mabos-packages/releases/download/repo
```

Then `sudo pacman -Sy mabos-gtk4` (it asks to replace `gtk4`) and restart the GTK 4 apps once.
Later versions come with `pacman -Syu`.

## How it is built

`.github/workflows/build.yml` runs every day, on every push to `main` and by hand: in an
`archlinux:base-devel` container, `scripts/build.sh` follows Arch's packaging (committing the new
`PKGBUILD` when it changed), builds the package when its version is not in the `repo` release yet,
signs it and the database with the key kept in the workflow's secrets, and replaces the release's
files. If the patch stops applying to a new GTK, the build fails and the last published version stays.

## Licenses

The patch is a change to GTK and under GTK's license, LGPL-2.1-or-later. The packaging follows Arch's
gtk4 packaging (0BSD); the scripts here are 0BSD too.
