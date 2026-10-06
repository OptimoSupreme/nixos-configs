# Installer ISO

A bootable live image of this flake: my own desktop (`personal_environment`)
with NixOS's graphical installer on it, which clones this repo into the
live user's home once it is online. Boot it on a machine to be set up,
install a stock NixOS with Calamares, then hand the machine over to the
repo. This file comes down with the clone, so it is also the walkthrough
for that.

## What's on it

- **The desktop nazgul and balrog run**: GNOME with the extensions, dconf
  defaults, Ptyxis, Codium, podman and libvirt, CAC support. Calamares is
  first in the dock and opens by itself at login.
- **This repo, fresh from GitHub.** The stick carries no copy of it.
  Once the network is up, `nixos-configs-clone.service` clones `main`
  over HTTPS into `~/nixos-configs`, so the live session always starts
  from the latest configs, however old the stick. Wired networks connect
  by themselves; on WiFi, join from the top bar and the clone follows
  within 15 seconds (the service retries until it gets through).
  `systemctl status nixos-configs-clone` shows where it is. It is a real
  git clone, so `git pull` refreshes it; build from it as `path:` (see
  "Hand the machine to the repo").
- **Two kernels in the boot menu.** The default entry is the LTS series
  with ZFS, as the installer profile ships it. The "(latest kernel)" entry
  is the newest stable kernel, for hardware LTS doesn't know yet, without
  ZFS. Every menu entry (nomodeset, copytoram, …) comes in both flavours.
- **What the stock graphical ISO has**: gparted, the NixOS manual,
  partitioning and rescue tools, `nixos-install`, `nixos-generate-config`.
- **Live login**: GNOME logs in as `nixos`, which has an empty password
  and passwordless sudo. sshd runs from boot; set a password first
  (`passwd`), then `ssh nixos@<ip>`. Nothing announces the hostname on the
  LAN, so find the address with `ip -br a`.

## Building

The image is named like the official GNOME ISO,
`nixos-gnome-<version>-x86_64-linux.iso`, and carries the same volume
label; the version string tells them apart. On a machine with nix, from a
clone:

```bash
nix build .#installer-iso
ls -l result/iso/
```

On a machine without nix, build it in a container with podman:

```bash
podman container exists nixos-iso-build ||
  podman create --name nixos-iso-build --security-opt label=disable \
    -v "$PWD":/work:ro -v ~/Downloads:/out docker.io/nixos/nix:latest \
    bash -c 'iso=$(nix --extra-experimental-features "nix-command flakes" \
      build --no-link --print-out-paths "path:/work#installer-iso") && cp "$iso"/iso/*.iso /out/'
podman start -a nixos-iso-build && podman rm nixos-iso-build &&
  podman rmi docker.io/nixos/nix:latest
```

`path:/work` (rather than the git URL nix would infer) builds the working
tree as it is, untracked files included; only the installer's own config
ends up in the image, never the repo. `label=disable` keeps SELinux from
relabeling the repo. Rootless podman maps the container's root to you, so
the ISO that lands in `~/Downloads` is yours.

Everything nix downloads lives in the container. The container and the
`nixos/nix` image are removed only once the build and the copy into
`~/Downloads` both succeed, which leaves just the ISO behind. If anything
fails, both stay; run the same block again and it restarts that container,
keeping what it already downloaded. To give up instead,
`podman rm nixos-iso-build && podman rmi docker.io/nixos/nix:latest`.

Nothing compiles: the time is download plus squashfs compression. The
repo comes from GitHub at boot, so an old stick still installs the latest
configs; rebuild it only when the live system itself should change (the
desktop, the kernels, a newer NixOS release). Nothing builds it
automatically; the weekly Action only checks that it still evaluates.

## Installing a machine

UEFI or legacy BIOS both boot it; Secure Boot has to be off to boot it.
A host with `secure_boot.nix` turns it back on after the install (see
"Finishing the machine"). Take the default menu entry unless the hardware
needs the latest kernel.

### 1. Calamares

GNOME logs in and Calamares opens. What matters in it:

- **Partitions**: "Erase disk", and pick **btrfs** in the filesystem
  dropdown, whose default is ext4. Tick **Encrypt system** and set a
  passphrase if the machine is to unlock with its TPM; adding encryption
  later means a reinstall in practice. Swap: none, the host config brings zram.
  Calamares makes `home` and `nix` subvolumes on the btrfs, which is what
  `btrfs_snapshots.nix` expects.
- **Users**: the username must be the one the host file declares (`justin`
  on my machines, the person's name on a managed one). Same name, and the
  password set here carries over. The hostname is free, the repo sets it.

Calamares writes `/etc/nixos/configuration.nix` and, from
`nixos-generate-config`, `/etc/nixos/hardware-configuration.nix`, which
holds the LUKS device and the subvolume mounts. Reboot into the new
system. Network is on (NetworkManager); at a text console `nmtui` connects
to wifi.

### 2. Hand the machine to the repo

On the installed machine, clone the repo. The stock install has no git,
so borrow it from nixpkgs for the clone; the repo config brings git for
good:

```bash
nix-shell -p git --run 'git clone https://github.com/OptimoSupreme/nixos-configs.git ~/nixos-configs'
```

Build from it as `path:$HOME/nixos-configs`, never the bare
`~/nixos-configs`. A bare path to a git checkout makes nix read it through
git, and as root (under sudo) it then refuses a repo the user owns
("repository path is not owned by current user"); it would also ignore
the new, untracked host directory. `path:` takes the directory as it is.

Then, in the clone:

1. Create the host from the template. Groups are `hosts/workstations`,
   `hosts/appliances` and `hosts/servers`:

   ```bash
   mkdir hosts/workstations/<name>
   cp hosts/workstations/template.nix hosts/workstations/<name>/default.nix
   cp /etc/nixos/hardware-configuration.nix hosts/workstations/<name>/
   ```

2. Work down `default.nix`; everything is a line to uncomment, and nazgul
   and jeff-laptop show the result.
   - **Modules**: `maintenance.nix` on every host (upgrades, GC, flakes).
     `firefox.nix` and `fastfetch.nix` as wanted. `btrfs_snapshots.nix` on a
     btrfs install. `tpm_decryption.nix` only on an encrypted install; it
     refuses to evaluate without a LUKS device. `secure_boot.nix` on a UEFI
     machine that should boot with Secure Boot on; it takes over from
     systemd-boot, so keep the UEFI boot lines. Exactly one environment:
     `general_environment.nix` for a managed machine,
     `personal_environment.nix` for one of mine. They are siblings, never
     both.
   - **Boot**: systemd-boot for UEFI, GRUB for BIOS. **Kernel**: LTS or
     latest. **Swap**: keep zram; the swapfile block is optional.
   - **Hostname** (it must match the flake.nix entry), the **user** block
     renamed from `changeme` to the Calamares username, and the **GPU**
     lines the hardware needs.

3. Register the host in `flake.nix`, under its group, with the attribute
   name equal to the hostname:

   ```nix
   <name> = mkHost ./hosts/workstations/<name>;
   ```

   A Jovian Steam machine registers with `mkHostOn nixpkgs-unstable`
   instead, like gollum.

4. Build and stage the new system, then reboot into it:

   ```bash
   sudo nixos-rebuild boot --flake path:$HOME/nixos-configs#<name>
   sudo systemctl reboot
   ```

   `boot` rather than `switch`: on a fresh install a switch leaves the
   display manager down until the reboot anyway. With `secure_boot.nix`
   the first rebuild compiles Lanzaboote's `lzbt`, which no binary cache
   carries, and the first boot reboots once more by itself (see "Finishing
   the machine"). On the home LAN, add
   `--option http2 false` to the rebuild; cache.nixos.org is several times
   faster over parallel connections from here.

The declared user keeps the password Calamares set, because users are
mutable and an existing account is left alone. If the names didn't match,
the declared account exists without a password: `sudo passwd <user>`.
Mind the reverse too: dropping a user declaration from a host file
**deletes that account** on the next rebuild (NixOS lists declared users in
`/var/lib/nixos/declarative-users`); remove the name from that file first
to hand the account over to mutable management.

### 3. Updates

`maintenance.nix` makes every host pull this repo from GitHub daily, at
10:00 local plus up to 20 minutes, and run `nixos-rebuild boot`: the new
generation is **staged for the next reboot, never applied mid-session**,
and nothing reboots by itself. One thing has to be true for that to work.

**The host has to be on `main`.** The daily pull builds what GitHub has,
so commit the new host directory, hardware config included, and push, from
a real clone with push access (balrog, or wherever you are logged in to
GitHub). There is nothing to register on the host side: the repo is public
and the pull fetches it over HTTPS (`github:OptimoSupreme/nixos-configs`),
so the machine holds no credential for it. Confirm the first pull by hand:

```bash
sudo systemctl start nixos-upgrade.service && journalctl -u nixos-upgrade -f
systemctl list-timers nixos-upgrade             # the daily schedule
```

Package updates only reach machines when `flake.lock` moves. A GitHub
Action bumps it weekly (Sunday 04:00 UTC), gated on `nix flake check`, so a
lock that breaks any host never lands on `main`. That check evaluates every
registered host, which is why the hardware config has to be committed.
Hosts pick the new lock up at their next daily pull. The same module runs
a weekly garbage collection (generations older than 14 days) and a weekly
store dedup.

To apply a change now, from any clone (`path:` for the reason in
"Hand the machine to the repo"):

```bash
sudo nixos-rebuild switch --flake path:$HOME/nixos-configs#<name>
```

Roll back by picking an older generation in the boot menu (the last 10 are
kept), or with `sudo nixos-rebuild switch --rollback`.

### 4. Finishing the machine

- **Secure Boot**, with `secure_boot.nix`. The first boot into the repo
  config generates the machine's own keys in `/var/lib/sbctl` (they never
  leave it), stages them on the ESP, signs everything and reboots by
  itself. systemd-boot enrolls the keys, alongside Microsoft's, on any boot
  where the firmware is in **Setup Mode**; until then the machine simply
  boots with Secure Boot off. To get there, `sudo systemctl reboot
  --firmware-setup`, turn Secure Boot on and reset its keys to Setup Mode
  (the wording varies by vendor; skip any option that also erases the dbx
  revocation list), save and exit. Then check:

  ```bash
  sudo sbctl status   # Secure Boot: Enabled, Setup Mode: Disabled
  sudo sbctl verify   # every file on the ESP signed, except the kernel-* ones
  ```

  A reinstall generates new keys, so it needs Setup Mode again.
- **TPM unlock**, on an encrypted install, once, after the first boot into
  the repo config, and after Secure Boot is on if the host has it (turning
  it on changes PCR 7): `sudo enable-tpm-decryption`. It asks for the LUKS
  passphrase and enrolls the TPM, bound to PCR 7 (the Secure Boot state);
  the passphrase stays as the fallback. If the disk stops unlocking, run it
  again. Without Secure Boot this protects a pulled drive, not the machine
  itself.
- **Firmware updates** can wipe the UEFI boot entries; an HP BIOS update
  did on nazgul, and the firmware did not fall back to the default loader.
  The disk was intact. Recreate the entry, then boot normally:

  ```bash
  sudo efibootmgr --create --disk /dev/nvme0n1 --part 1 \
    --loader '\EFI\systemd\systemd-bootx64.efi' --label 'Linux Boot Manager'
  ```

- **Snapshots**: snapper takes timeline snapshots of `/home` (2 hourly,
  7 daily, 4 weekly) into `/home/.snapshots`; browse them with Btrfs
  Assistant or `snapper -c home list`. System state needs none: every
  generation is a bootable rollback point.
- **Fingerprint login**: enroll under Settings → Users on the machine.
- **My flatpaks** (personal_environment) install themselves at the first
  boot with network; `systemctl status flatpak-apps` shows progress.
- **ssh into a host**: sshd is installed but not started at boot. Start it
  when needed with `sudo systemctl start sshd` and log in as the user;
  root can't log in over ssh.
- **Secrets stay on the box.** Nothing in the repo is secret: the user's
  password is whatever the installer set (`sudo passwd <user>` changes it),
  WiFi is joined on the box (`nmcli dev wifi connect <ssid> password
  <psk>`), and a host that needs more (palantir's Jellyfin key and weather
  location) reads a file under `/var/lib` described in its README. All of
  it survives rebuilds; a reinstall means setting it again.

## Installing from the flake directly

The NixOS way, without Calamares, for a hand-partitioned disk. With the
target partitioned, formatted and mounted on `/mnt` (an ESP on `/boot`,
btrfs with `home` and `nix` subvolumes, LUKS if wanted), from the live
session:

```bash
cd ~/nixos-configs
# create the host as above; for its hardware config:
nixos-generate-config --root /mnt --show-hardware-config > hosts/<group>/<name>/hardware-configuration.nix
sudo nixos-install --flake path:$HOME/nixos-configs#<name> --no-root-passwd
sudo nixos-enter --root /mnt -c 'passwd <user>'    # the declared user has no password yet
```

Then continue at "Updates". The clone goes with the live session, so
bring the new host directory over to a clone with push access, then
commit and push it.

## Mind

- The stick carries no copy of the repo, and nothing in the repo is
  secret anyway, so the stick needs no more care than any other install
  disk. Without network there is no repo, but an install needs the
  network regardless.
- Physical access to the live stick is full access, by design: `nixos` has
  no password, sudo asks for none, and root can log in over ssh once it
  has been given a password.
