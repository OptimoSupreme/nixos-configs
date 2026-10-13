# TODO

Open work on the fleet. Each item says what, why, and how to tell it is done.

## 1. Early KMS module for every GPU vendor

Loading the GPU's kernel mode setting driver in the initrd gives native
resolution from the first frame: Plymouth, the LUKS prompt and the console
all render at the panel's resolution instead of the firmware's. The right
knob is different for each vendor, and today only palantir
(`boot.initrd.kernelModules = [ "i915" ]`) and balrog
(`hardware.amdgpu.initrd.enable`, set by its nixos-hardware module) do it.

Write a module, or a section of `workstation_template.nix`, that makes the
correct setting one line to pick:

- AMD: `hardware.amdgpu.initrd.enable = true`.
- Intel: `boot.initrd.kernelModules = [ "i915" ]`, or `[ "xe" ]` on Lunar Lake,
  Battlemage and newer.
- Nvidia: `hardware.nvidia.modesetting.enable = true`, the
  `nvidia nvidia_modeset nvidia_uvm nvidia_drm` modules in
  `boot.initrd.kernelModules`, and `nvidia-drm.fbdev=1` in `boot.kernelParams`.
  Check whether the open kernel module needs anything different.
- Hybrid laptops: usually the iGPU driver only, since that is what drives the
  panel.

Decide where it lives. The fleet rule is no custom options until three hosts
vary the same thing, so the first pass is probably a commented menu in
`workstation_template.nix` next to the existing GPU block, mirrored into
`nazgul` and `jeff-laptop`, with a `modules/` option only if the Nvidia case
turns out to be more than a few lines.

Done when: every registered desktop host has early KMS on and the template
shows the choice for all three vendors.

## 2. Customize the shell

Every host runs stock bash with the default prompt. The only shell setup in
the repo is the microfetch hook in `modules/desktop.nix`. Decide what the
interactive shell should look like across the fleet (prompt, aliases,
completion, history, whether to stay on bash or move to zsh or fish) and put
it in a module that both environments import.

Keep it system-level: no home-manager, so the config goes through
`programs.bash` (or the chosen shell's `programs.*` block) and
`environment.shellAliases`, not per-user dotfiles. Client machines should get
the same defaults as Justin's, so it belongs under `desktop.nix` or a module
both environments import, not in `personal_environment.nix` alone.

Done when: a shell module is imported by both environments and every
registered desktop host evaluates with it.

## 3. Wake from sleep automatic updates (option)
Add to template (potentially as an import), comment that it's an option best for desktops that are left powered on.

## 4. Sleep then shutdown (option)
Add to template (potentially as an import), comment that it's an option best for laptops to save battery.

## 5. Move TPM unlock off a literal PCR 7 binding

`modules/tpm_decryption.nix` enrolls with `--tpm2-pcrs=7`. systemd 258
stopped defaulting to that and recommends systemd-pcrlock policies for
PCR 7 combined with signed PCR 11; a literal PCR 7 seal is invalidated by
every fwupd dbx update and falls back to the passphrase. It still works on
systemd 260, so this is not urgent.

What Lanzaboote v1.2.0 offers (checked 2026-10-12): `measuredBoot` builds
a systemd-pcrlock policy for any of PCRs 0 to 4 and 7, and
`measuredBoot.autoCryptenroll` migrates a LUKS2 volume from a static PCR
seal to that policy. It has nothing for signed PCR 11, so the route is
pcrlock, not signed UKI policies. Constraints: `configurationLimit` drops
from 10 to at most 4 (systemd-pcrlock policy size), systemd still calls
pcrlock experimental, the guide recommends `--tpm2-with-pin` on attended
machines, and `systemd-pcrlock is-supported` must say yes on each host.

In progress on `feat/measured-boot` (2026-10-12). `secure_boot.nix` turns
on `measuredBoot` with `pcrs = [ 0 4 7 ]` and `autoCryptenroll` by default
whenever the host declares a LUKS device, and `enable-tpm-decryption`
enrolls the pcrlock policy instead of PCR 7 on such a host. No PIN: the
fleet enrolls unattended and the client laptops should not gain a prompt
before login. The host list changed on inspection: jeff-laptop is
encrypted but had no Secure Boot, so it gains `secure_boot.nix`; its TPM
(Infineon SLB9670, firmware 7.62) answers `obsolete` to
`systemd-pcrlock is-supported`, so it opts out of measured boot and keeps
the PCR 7 seal, now meaningful with Secure Boot on. saruman has Secure
Boot and no encryption, so measured boot stays off there. balrog has no
LUKS device in the repo yet (its hardware configuration waits on the
board), so it only joins once it does.

Canary: jeff-laptop proves Secure Boot plus the opt-out path on the
branch. The pcrlock path still needs a first host: run `is-supported` on
nazgul and emily-laptop before merging, and if neither says yes the
measured boot default is dead weight and should come out. Once merged,
the hosts that qualify migrate on their own at the next daily upgrade and
reboot (`installer/README.md`, "Finishing the machine").

Done when: every encrypted host whose TPM qualifies unlocks from a pcrlock
policy (its LUKS header carries a `tpm2_pcrlock` token), a dbx or firmware
update there costs at most one passphrase boot and recovers without
re-enrollment, and the enrollment script encodes the policy.

#### Waiting on upstream ####

Items that cannot be finished yet, or that are a heads-up for a future
change. Nothing to do until the named event happens.

### Drop two workarounds once their nixpkgs backports reach nixos-26.05

Both fixes are on nixpkgs master; the fleet waits on the release-26.05
backports and the weekly lock bump that follows each merge.

- Fingerprint enrolment: `environment.extraInit` in `modules/desktop.nix`
  puts gdm's gsettings schema on `XDG_DATA_DIRS`. Delete it once
  https://github.com/NixOS/nixpkgs/pull/572210 is merged.
- Impatience: `modules/desktop.nix` uses
  `gnome50Extensions."impatience@gfxmonk.net"` because the manual package
  on 26.05 stops at GNOME 49. Switch back to `gnomeExtensions.impatience`
  and drop the comment once https://github.com/NixOS/nixpkgs/pull/573338 is
  merged.

Done when: both lines are gone and every registered desktop host evaluates.

### Expect changes at the NixOS 26.11 bump (GNOME 51)

Two things the 26.11 upgrade will bring that touch this repo:

- GDM 51 no longer allows fingerprint-only login; fingerprint becomes
  re-authentication only. The fprintd hosts will behave differently at the
  login screen and the fingerprint line in `installer/README.md` needs
  rewording.
- Fedora 45 and GNOME OS replace gnome-keyring with oo7 as the Secrets
  Service. nixpkgs has the packages but no NixOS module yet; check whether
  26.11 wires it into the GNOME module and whether anything (CAC, Chromium
  NSS database) notices.

Done when: the fleet is on 26.11 and both points are checked off or
reworked.
