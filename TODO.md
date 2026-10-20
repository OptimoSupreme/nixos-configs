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

## 2. Wake from sleep automatic updates
Add to template, comment that it's an option best for desktops that are left powered on. Need to decide how I want to implement this, whether it should be an optional import module or something else.

## 3. Sleep then shutdown
Add to template, comment that it's an option best for laptops to save battery. Need to decide how I want to implement this, whether it should be an optional import module or something else.

## 4. PS1 titles look bad when SSH'd

## 5. What's up with the lanzaboot 4 generation limit? Should we make maintenance.nix match?

## 6. Choose a license

#### Waiting on upstream ####

Items that cannot be finished yet, or that are a heads-up for a future
change. Nothing to do until the named event happens.

## 1. Drop workarounds once their nixpkgs backports reach nixos-26.05

Both fixes are on nixpkgs master; the fleet waits on the release-26.05
backports and the weekly lock bump that follows each merge.

- Fingerprint enrolment: `environment.extraInit` in `modules/workstation_core.nix`
  puts gdm's gsettings schema on `XDG_DATA_DIRS`. Delete it once
  https://github.com/NixOS/nixpkgs/pull/572210 is merged.
- Impatience: `modules/workstation_core.nix` uses
  `gnome50Extensions."impatience@gfxmonk.net"` because the manual package
  on 26.05 stops at GNOME 49. Switch back to `gnomeExtensions.impatience`
  and drop the comment once https://github.com/NixOS/nixpkgs/pull/573338 is
  merged.

Done when: both lines are gone and every registered desktop host evaluates.

## 2. Expect changes at the NixOS 26.11 bump

Three things the 26.11 upgrade will bring that touch this repo:

- GDM 51 no longer allows fingerprint-only login; fingerprint becomes
  re-authentication only. The fprintd hosts will behave differently at the
  login screen and the fingerprint line in `installer/README.md` needs
  rewording.
- Fedora 45 and GNOME OS replace gnome-keyring with oo7 as the Secrets
  Service. nixpkgs has the packages but no NixOS module yet; check whether
  26.11 wires it into the GNOME module and whether anything (CAC, Chromium
  NSS database) notices.
- Blur my Shell: `blurMyShell` in `modules/workstation_core.nix` pins version 75 from
  extensions.gnome.org because 26.05 ships 72, which flickers blurred windows
  in the overview (fixed in 73). Release branches never get extension
  updates, so this waits for 26.11. Replace it with
  `gnomeExtensions.blur-my-shell` and delete `assets/blur-my-shell-metadata.json`
  once `gnomeExtensions.blur-my-shell.version` is 73 or more. At the same
  time check that `gnomeRoundedBlur` in `modules/workstation_core.nix` still builds against
  mutter 51 and bump its tag if upstream needed changes.

Done when: the fleet is on 26.11 and all three points are checked off or
reworked.
