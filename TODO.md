# TODO

Open work on the fleet. Each item says what, why, and how to tell it is done.

## 1. Stop sleep_then_shutdown powering off a plugged-in laptop

`modules/sleep_then_shutdown.nix` powers off 6 hours into any suspend, even
on AC, where there is no battery to save. Better: never power off while
plugged in, and power off 6 hours after being unplugged if still asleep.

See if this can be done without waking the laptop up periodically, since the whole
point is to save battery. Otherwise I think I'd pass.

Done when: the loop is either in the module, working on nazgul and
emily-laptop, or rejected here with the reason.

## 2. Investigate a lighter workstation configuration for low-spec machines

Every workstation gets the full desktop, including extras that cost GPU and
memory a low-spec machine may not have. Idea: move them out of
`modules/workstation_core.nix` into an opt-in `modules/desktop_luxuries.nix`.
Hosts with resources to spare import it; low-spec hosts leave it out.

Candidates to move:

- Blur my Shell: `blurMyShell`, `gnomeRoundedBlur` and its `sessionPath` line.
- File indexing: localsearch and tinysparql. The GNOME module enables both,
  so leaving out a module is not enough: core has to turn them off and
  `desktop_luxuries.nix` back on. Check what still needs them, since the
  Nautilus search provider is already disabled in dconf but its in-app search
  uses the index.
- Dash to Panel effects: `trans-use-dynamic-opacity` and
  `focus-highlight-dominant`, if they make a measurable difference.

Leave in core: Impatience (shorter animations help a slow machine) and GNOME
Software (nothing else in this repo updates Flatpaks).

To work out:

- dconf arrays replace rather than merge, so the module cannot append to
  `enabled-extensions`. Simplest is to leave the UUID and blur settings in both
  environment keyfiles, if GNOME ignores them with the extension absent. Also
  check the panel is still legible at `trans-panel-opacity=0.5` without blur.
- Existing hosts lose everything moved unless they import the module in the
  same change: balrog, nazgul, saruman, emily-laptop, jeff-laptop, wormtongue
  and `hosts/workstation_template.nix`. `installer/default.nix` needs a
  decision too.
- Update the Blur my Shell point under 26.11 below and the module list in
  `CLAUDE.md`.

Done when: idle memory and GPU load are compared with and without the module
on low-spec hardware, and the module is in use or rejected here with the
reason.

## 3. Rename steam-maintenance to jovian-decky-updater

The name should say what it is: a Decky updater for Jovian hosts.
`modules/maintenance/jovian.nix` keeps its name. Everything else moves: the
GitHub repo (`OptimoSupreme/jovian-decky-updater` is free), the code in it
(package, binary, `services.steam-maintenance`, units, `STEAM_MAINTENANCE_*`,
run and state directories, the Decky plugin directory), the flake input, the
two cache workflows, `CLAUDE.md`, and the Cachix cache.

To work out:

- Cachix has no rename, so this means a new cache with a new key, and maybe
  a new `CACHIX_AUTH_TOKEN`. gollum and smeagol read substituters from their
  running config, so switching CI to the new cache in the same commit would
  make their next update build the kernel and Mesa locally. Two PRs: first
  rename the input and service and trust both caches while CI still pushes to
  the old one, then accept the update on both hosts; second, point CI at the
  new cache and drop the old one (a cold CI build).
- The `decky-loader` `preStart` only links the new plugin directory, so the
  old link stays and Decky shows two System Update plugins. Remove the old
  link there.
- The new state directory starts empty: deferrals and snooze reset and the
  check is due at once. Harmless; delete the old directory, no migration.
- GitHub redirects the old repo URL as long as nothing reuses the name.

Done when: nothing in either repo says steam-maintenance, gollum and smeagol
are updated from the new cache with one System Update plugin, and the old
cache is deleted.

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

Four things the 26.11 upgrade will bring that touch this repo:

- GDM 51 no longer allows fingerprint-only login; fingerprint becomes
  re-authentication only. The fprintd hosts will behave differently at the
  login screen.
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
- Scripted stage 1 is gone on unstable, and `boot.initrd.verbose` with it;
  setting it is now an assertion failure (`gollum` already hit this). Drop
  the line from `modules/workstation_core.nix` when the workstations move.

Done when: the fleet is on 26.11 and all four points are checked off or
reworked.

## 3. Lift the 4-generation cap on measured boot hosts

`secure_boot.nix` sets `boot.lanzaboote.configurationLimit = 4` on measured
boot hosts because the lanzaboote module asserts it. systemd-pcrlock puts
every alternative value for a PCR into one `TPM2_PolicyOR`, which takes at
most 8 digests, and lanzaboote 1.2 covers a bootloader update in the policy,
so PCR 4 holds 2 loader variants times 4 generations. The cap is only on
boot entries; the 5 store generations the maintenance modules keep are
independent and stay as is. Upstream fix: https://github.com/systemd/systemd/pull/43982
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
TV has it) works from a cold boot. Item 7 (the HPO VPG/AFMT kernel patch) is
separate: FRL carried no InfoFrames or audio on this GPU until that patch,
and the flag alone does not fix it.

## 5. Drop the screencast audio extension once GNOME records audio itself

The built-in screen recorder is video only. `modules/workstation_core.nix`
installs `screencast.extra.feature@wissle.me` (from nixpkgs-unstable, since
26.05 ships version 7) and both dconf keyfiles enable it, which adds Desktop
and Mic toggles to the screenshot UI by passing the screencast service a
pipeline with a `pulsesrc` monitor branch. Upstream tracks native audio in
https://gitlab.gnome.org/GNOME/gnome-shell/-/issues/5524, open with no merge
request attached. In the meantime, at the 26.11 bump, check whether
`gnomeExtensions.screencast-extra-feature.version` is 8 or more and switch
the unstable pull back to the stable package if so.

Done when: the GNOME release in `flake.lock` records desktop audio from the
screenshot UI on its own, the `screencastExtraFeature` lines and the UUID in
`assets/dconf/personal_environment/00-defaults` and
`assets/dconf/client_environment/00-defaults` are gone, and every registered
desktop host evaluates.

## 6. Check microfetch has the P/E core fix at the 26.11 bump

microfetch 1.1.0 (on 26.05) and 1.2.0 (on unstable) report the thread count
as the CPU core count. https://github.com/NotAShelf/microfetch/pull/112
counts P and E cores instead; it merged 2026-10-30 and ships in v1.2.1 and
later. Stable never takes version bumps, so nothing to do until the fleet
moves to 26.11. At that point check that `microfetch.version` on
release-26.11 is 1.2.1 or more. If it is not, ask for a nixpkgs backport
first; if that is refused, override `microfetch` in
`modules/workstation_core.nix` the way `work_patch.nix` does for freerdp.

Done when: `microfetch` on the registered desktop hosts prints the core
count, from the stable package with no override.

## 7. Drop gollum's HPO VPG/AFMT kernel patch once upstream has the fix

On DCN 3.0.2 (the RX 6600) amdgpu wires the HDMI FRL stream encoder to the
DIG5 block's packet generator and audio formatter instead of the HPO's own,
so every 4K120 FRL mode reaches the TV as SDR and silent, with the kernel
convinced it sent HDR. Reported as
https://gitlab.freedesktop.org/drm/amd/-/issues/6086 with a fix,
`hosts/appliances/gollum/0001-drm-amd-display-use-the-HPO-VPG-AFMT-instance-on-DCN-3.0.2.patch`,
which `hosts/appliances/gollum/default.nix` applies through
`boot.kernelPatches` and which was confirmed on gollum on 2026-11-03 (HDR10
and audio back at 4K120). Each kernel bump on unstable rebuilds the kernel
on gollum, about 90 minutes, unless the cache-gollum workflow has already
built it. The patch went to amd-gfx on 2026-11-03:
https://lore.kernel.org/amd-gfx/20261103143248.59765-1-jward92@gmail.com/

- Watch the issue and the amd-gfx thread for the patch (or an equivalent
  fix) landing; the `Fixes:` target is 70ed4679c512.
- If a kernel bump makes the patch fail to apply, check
  `dcn302_resource.c`'s `dcn302_hpo_frl_stream_encoder_create()` first: if
  it no longer says `vpg_inst = 5`, upstream fixed it and the patch goes;
  otherwise rebase the header hunk.

Done when: gollum's `linuxPackages_latest` contains the fix, the
`boot.kernelPatches` block and the patch file are deleted, gollum evaluates,
and 4K120 still shows HDR10 with audio.