# TODO

Open work on the fleet. Each item says what, why, and how to tell it is done.

## 1. Move the Steam updater from a library app to a Decky plugin

Decision (2026-11-03): go, keeping the library tile as a fallback. A Decky
plugin is a React panel injected into Steam's UI plus a Python backend
that can run as root (`"flags": ["root"]` in `plugin.json`), so the
updater becomes reachable from the Quick Access Menu mid-game and can
toast or open a modal instead of launching a shortcut. Decky breaks for a
few days after some Steam client updates, which is why the tile stays
until the plugin has survived a couple of them.

Plan, `steam-maintenance` repo:

- Keep the worker as is: `steam-maintenance-upgrade.service`, the cache
  check, `status.json`, the heartbeat before reboot, and the home-screen
  gate in `check.rs`. The weekly timer keeps refusing to prompt while a game
  has gamescope focus; only how the prompt appears changes.
- Add a `plugin/` directory built by the flake into a Decky plugin: the
  React panel reads `status.json` and shows Update, Later and Up to date;
  the backend starts and stops the root unit directly, so the polkit rule
  can go once the tile is retired.
- Teach `check` a second target: a Decky toast or modal through the loader
  when the plugin is present, else the `steam://` shortcut as today.
- Export the plugin as a package the module links into
  `/var/lib/decky-loader/plugins` from the store, read-only, so a deploy
  brings it along and Decky's updater leaves it alone.

Plan, this repo: nothing beyond the weekly lock bump and the cache
workflows, which already rebuild on it.

Done when: the plugin is in the flake input, both hosts show it in the
Quick Access Menu, the weekly prompt appears through it, and the tile is
removed after it has held up across Steam client updates.

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
