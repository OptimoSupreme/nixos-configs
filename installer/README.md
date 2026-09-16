# Installer ISO

A bootable live image of this flake: my own desktop (`personal_environment`)
with NixOS's graphical installer on it, and a copy of this repo in the live
user's home. Boot it on a machine to be set up, install a stock NixOS with
Calamares, then hand the machine over to the repo. This file is on the
stick, so it is also the walkthrough for that.

## What's on it

- **The desktop nazgul and balrog run**: GNOME with the extensions, dconf
  defaults, Ptyxis, Codium, podman and libvirt, CAC support. Calamares is
  first in the dock and opens by itself at login.
- **This repo.** `~/nixos-configs` in the live user's home is a
  writable copy, made at boot, so Files shows it at once and it can be
  built from as is. `/iso/nixos-configs` is the read-only original on the
  stick. Both are the flake source as built, without `.git`.
- **The locked nixpkgs**, in the store, so `nix` commands against that copy
  resolve the flake's input without a download. Only `nixpkgs` is bundled;
  a host on `nixpkgs-unstable` (gollum) still fetches.
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

On a machine without nix the:

```bash
podman run --rm -v nixstore:/nix --security-opt label=disable \
  -v "$PWD":/work:ro -v ~/Downloads:/out docker.io/nixos/nix:latest \
  bash -c 'iso=$(nix --extra-experimental-features "nix-command flakes" \
    build --no-link --print-out-paths "path:/work#installer-iso") && cp "$iso"/iso/*.iso /out/'
```

`path:/work` (rather than the git URL nix would infer) means the copy on
the ISO is the working tree as it is, untracked files included, so build
from a clean, committed tree to ship exactly what's on `main`. The config
filters `.git` out of the copy. `label=disable` keeps SELinux from
relabeling the repo. Rootless podman maps the container's root to you, so
the ISO that lands in `~/Downloads` is yours.

Nothing compiles: the time is download plus squashfs compression. The
image is a snapshot of the repo, so rebuild when the configs change enough
to matter. Nothing builds it automatically; the weekly Action only checks
that it still evaluates.

## Installing a machine

UEFI or legacy BIOS both boot it; Secure Boot has to be off, as it is for
the installed system. Take the default menu entry unless the hardware
needs the latest kernel.

### 1. Calamares

GNOME logs in and Calamares opens. What matters in it:

- **Desktop**: GNOME, the default. The choice only affects the first boot,
  the repo replaces the whole config in the next step, but "No desktop"
  leaves you at a text console for it.
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

On the installed machine, get the repo. The stick still has it: plug it
back in, it mounts by its volume label, and copy `nixos-configs` off it to
`~/nixos-configs`. Or clone from GitHub with a key that has access. A copy
from the stick has no `.git`; that's fine for building, and it avoids a
trap: nix reads a git checkout through git and ignores untracked files, so
in a real clone the new host directory has to be `git add`ed before nix
sees it.

Then, in the copy:

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
     refuses to evaluate without a LUKS device. Exactly one environment:
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
   sudo nixos-rebuild boot --flake ~/nixos-configs#<name>
   sudo systemctl reboot
   ```

   `boot` rather than `switch`: on a fresh install a switch leaves the
   display manager down until the reboot anyway. On the home LAN, add
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

To apply a change now, from any clone or the stick copy:

```bash
sudo nixos-rebuild switch --flake ~/nixos-configs#<name>
```

Roll back by picking an older generation in the boot menu (the last 10 are
kept), or with `sudo nixos-rebuild switch --rollback`.

### 4. Finishing the machine

- **TPM unlock**, on an encrypted install, once, after the first boot into
  the repo config: `sudo enable-tpm-decryption`. It asks for the LUKS
  passphrase and enrolls the TPM, bound to PCR 7 (the Secure Boot state);
  the passphrase stays as the fallback. If the disk stops unlocking, run it
  again. Note that with Secure Boot off this protects a pulled drive, not
  the machine itself.
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
sudo nixos-install --flake ~/nixos-configs#<name> --no-root-passwd
sudo nixos-enter --root /mnt -c 'passwd <user>'    # the declared user has no password yet
```

Then continue at "Updates". `~/nixos-configs` is a plain directory, so the
new host directory needs no `git add`; don't `git init` it before building.

## Mind

- The stick carries the whole repo. Nothing in it is secret, so the stick
  needs no more care than any other install disk.
- Physical access to the live stick is full access, by design: `nixos` has
  no password, sudo asks for none, and root can log in over ssh once it
  has been given a password.
