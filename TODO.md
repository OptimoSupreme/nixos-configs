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

## 4. Installation guide
Try to make a guide that someone (especially me) could actually follow on their own for using the template to setup a new workstation, and everything they have to do to apply it, get it resisted in the repo, and be good to go. Doesn't need to cover building installation media, or even how to install nixos. I feel like that's pretty easy. I guess we could at least mention the installation options they should use if they planning on using certain features like installing on btrfs if they want snapshots, encrypted if they want tpm decryption, etc. etc.

#### Waiting on upstream ####

Items that cannot be finished yet, or that are a heads-up for a future
change. Nothing to do until the named event happens.

## 1. Drop the impatience workaround once its nixpkgs backport reaches nixos-26.05

The fix is on nixpkgs master; the fleet waits on the release-26.05 backport
and the weekly lock bump that follows the merge.

- Impatience: `modules/workstation_core.nix` uses
  `gnome50Extensions."impatience@gfxmonk.net"` because the manual package
  on 26.05 stops at GNOME 49. Switch back to `gnomeExtensions.impatience`
  and drop the comment once https://github.com/NixOS/nixpkgs/pull/573338 is
  merged.

Done when: the line is gone and every registered desktop host evaluates.

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

## 3. Lift the 4-generation cap on measured boot hosts

`secure_boot.nix` sets `boot.lanzaboote.configurationLimit = 4` on measured
boot hosts because the lanzaboote module asserts it. systemd-pcrlock puts
every alternative value for a PCR into one `TPM2_PolicyOR`, which takes at
most 8 digests, and lanzaboote 1.2 covers a bootloader update in the policy,
so PCR 4 holds 2 loader variants times 4 generations. The cap is only on
boot entries; `maintenance.nix` keeping 5 store generations is independent
and stays as is. Upstream fix: https://github.com/systemd/systemd/pull/43982
(PolicyOR tree) for https://github.com/systemd/systemd/issues/41526.

Done when: the lanzaboote release in `flake.lock` no longer asserts the
limit, the `configurationLimit` line in `secure_boot.nix` is deleted so
measured hosts fall back to `boot.loader.systemd-boot.configurationLimit`
like every other host, and nazgul and emily-laptop evaluate.

## 4. Drop gollum's HDMI FRL flag once kernel 7.4 turns it on by default

`hosts/appliances/gollum/default.nix` passes `amdgpu.dcfeaturemask=0x402` so
the RX 6600 can drive the TV at 4K120 over HDMI 2.1 Fixed Rate Link. Linux
7.2 added FRL but left it off because VRR over HDMI was not ready; 7.4 ships
VRR, FreeSync and ALLM and flips FRL on by default, at which point the flag
is redundant (and the mask replaces the driver default rather than adding to
it, so leaving it is a small liability).

- Delete the `amdgpu.dcfeaturemask` line once gollum's
  `linuxPackages_latest` is 7.4 or newer and 4K120 still appears without it.
- At the same time, if the TV connected then supports HDMI 2.1 VRR, turn on
  variable refresh in the Steam display settings and check that gamescope
  reports it active. VRR over HDMI did not exist on amdgpu before 7.4, so
  this has never been tried on gollum.

Done when: the flag is gone, gollum evaluates, and 4K120 (with VRR if the
TV has it) works from a cold boot.
