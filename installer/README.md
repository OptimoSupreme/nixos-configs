# Installing a machine

The ISO (`nix build .#installer-iso`) is this flake's own desktop with the
NixOS graphical installer on it, and a copy of this guide as `INSTALL.md`
in the live user's home. Boot it with Secure Boot off, install a stock
NixOS, then do the five steps below on the installed machine. nazgul and
jeff-laptop are finished examples of the result.

## 1. Calamares

What matters in it; everything else is the default:

- **Partitions**: Erase disk, filesystem **btrfs** (ext4 is the default).
  That is what `btrfs_snapshots.nix` wants; Calamares makes the `home` and
  `nix` subvolumes it expects. Tick **Encrypt system** if the machine is to
  unlock with its TPM (`tpm_decryption.nix`); encryption cannot be added
  later. Swap: none, the host config brings zram.
- **Users**: the username must be the one the host file will declare
  (`justin` on mine, the owner's name on a client's); the password set here
  carries over. The hostname does not matter, the repo sets it.

Reboot into the new system. A wired network is up by itself; `nmtui` joins
WiFi.

## 2. Create the host

```bash
nix-shell -p git --run 'git clone https://github.com/OptimoSupreme/nixos-configs.git ~/nixos-configs'
cd ~/nixos-configs
mkdir hosts/<group>/<name>
cp hosts/workstation_template.nix hosts/<group>/<name>/default.nix
cp /etc/nixos/hardware-configuration.nix hosts/<group>/<name>/
```

`<group>` is `workstations` for mine, `clients` for a machine managed for
someone else, named `<owner>-<kind>`. A new name of mine gets its entry in
`hosts/HOSTNAMES.md`. Leave `hardware-configuration.nix` exactly as
generated.

Work down `default.nix`; everything is a line to uncomment:

- **Modules**. A [nixos-hardware](https://github.com/NixOS/nixos-hardware)
  module for the board first, if there is one. `maintenance.nix` always,
  `firefox.nix` as wanted. `btrfs_snapshots.nix` on a btrfs install.
  `tpm_decryption.nix` only on an encrypted one (it refuses to evaluate
  otherwise). `secure_boot.nix` on UEFI, keeping the UEFI boot lines.
  Exactly one of `client_environment.nix` and `personal_environment.nix`;
  on top of the personal one, `home_patch.nix`, `work_patch.nix` or both.
- **Measured boot**. `secure_boot.nix` on an encrypted disk binds the TPM
  unlock to a pcrlock policy, which not every TPM supports. Ask first:

  ```bash
  /run/current-system/systemd/lib/systemd/systemd-pcrlock is-supported   # yes
  ```

  Anything else: add `boot.lanzaboote.measuredBoot.enable = false;` to the
  host, as jeff-laptop does.
- **Boot**: systemd-boot on UEFI, GRUB on BIOS. **Kernel**: LTS or latest.
  **Swapfile**: delete the block unless zram is not enough.
- **Hostname**, the **user** block renamed from `changeme` to the Calamares
  username, and the **GPU** lines the hardware needs.

## 3. Register, build, reboot

Add the host to `flake.nix` under its group; the attribute must equal the
hostname:

```nix
<name> = mkHost ./hosts/<group>/<name>;
```

Then stage the new system and reboot into it:

```bash
sudo nixos-rebuild boot --flake path:$HOME/nixos-configs#<name>
sudo systemctl reboot
```

`path:` matters: a bare path to a git checkout is read through git, which
under sudo rejects a repo you own and skips untracked files. `boot` rather
than `switch`: on a fresh install a switch leaves the display manager down
until the reboot anyway. With `secure_boot.nix` the first build compiles
Lanzaboote's `lzbt` (minutes, no cache has it) and the first boot generates
the Secure Boot keys and reboots once by itself.

If the username did not match Calamares, the declared account has no
password: `sudo passwd <user>`.

## 4. Firmware

- **Secure Boot** (`secure_boot.nix`). The keys live in `/var/lib/sbctl`
  and are enrolled on any boot where the firmware is in Setup Mode; until
  then the machine boots with Secure Boot off. `sudo systemctl reboot
  --firmware-setup`, turn Secure Boot on and reset its keys to Setup Mode
  (skip any option that also erases the dbx). HP firmware greys the
  clear-keys option out while Secure Boot is on: disable, clear, save,
  type the code it shows on reboot, then enable. Check:

  ```bash
  sudo sbctl status   # Secure Boot: Enabled, Setup Mode: Disabled
  ```

- **TPM unlock** (`tpm_decryption.nix`), after Secure Boot is on if the
  host has it, since turning it on changes PCR 7:

  ```bash
  sudo enable-tpm-decryption   # asks the LUKS passphrase; it stays as the fallback
  ```

  A firmware update may make one boot ask for the passphrase; if the disk
  keeps asking, run it again.

## 5. Put it on main

`maintenance.nix` has the host pull `main` from GitHub daily at 10:00 and
run `nixos-rebuild boot`, so updates are staged for the next reboot and
nothing reboots on its own. That only works once the host is on `main`:
from a clone with push access (this machine after `gh auth login`, or copy
the host directory to one), commit `hosts/<group>/<name>/` with its
hardware config and the `flake.nix` line, and open a pull request. CI
evaluates every registered host, which is why the hardware config is
committed. Merge, then confirm the first pull from the host:

```bash
sudo systemctl start nixos-upgrade.service && journalctl -u nixos-upgrade -f
```

Done. `sudo nixos-rebuild switch --flake path:$HOME/nixos-configs#<name>`
applies a repo change right away, and the boot menu holds the last
generations to roll back to.
