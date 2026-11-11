# MabOS packages

The pacman repository `[mabos]` of [MabOS](https://github.com/mabasterYT), an Arch Linux setup with
niri and Quickshell: Arch packages with small MabOS changes, signed with MabOS's key. Anyone on Arch
can use them. Each package has its own repository with its patch, README and build; this one only
signs what they build and publishes the repository.

## Packages

| Package | Replaces | What it changes |
| --- | --- | --- |
| [mabos-gtk4](https://github.com/mabasterYT/mabos-gtk4) | `gtk4` | Open GTK 4 windows read `~/.config/gtk-4.0/gtk.css` again when it changes, so a theme switch recolors running apps |
| [mabos-gtk3](https://github.com/mabasterYT/mabos-gtk3) | `gtk3` | The same for GTK 3 and `~/.config/gtk-3.0/gtk.css` |

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

Then install what you want, e.g. `sudo pacman -Syu mabos-gtk4` (it asks to replace `gtk4`), and
restart the apps that use it once. Later versions come with `pacman -Syu`.

## How it works

Each package repository follows Arch's packaging every day and builds its package, unsigned, into
its `package` release. Here, `.github/workflows/publish.yml` runs every three hours, on every push
and by hand: `scripts/publish.sh` takes each package from the repositories in `packages.txt` that
`[mabos]` does not have yet, signs it with MabOS's key (kept only in this repository's secrets), adds
it to the signed database and replaces the `repo` release's files. Only this repository writes the
database, so packages built at the same time never overwrite each other.

## Licenses

The scripts here are 0BSD. Each package repository states its own licenses.
