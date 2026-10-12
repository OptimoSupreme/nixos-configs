# Staleness audit report, 2026-10-12

Actionable findings only. Workarounds that are still needed, assets that
check out, and settings that match upstream are left out.

Baseline: nixpkgs `nixos-26.05` at 6fcc160 (2026-10-10): GNOME 50.5,
Firefox 157.0.1, kernels 6.18.55 LTS / 7.2.9, systemd 260.5, Nix 2.34.8,
BlueZ 5.86, OpenSC 0.27.1. Checked on saruman, which runs that exact
commit, so dconf keys, extension metadata and Firefox's omni.ja were
verified against installed bits. Every registered host evaluates; nixfmt
and parse are clean.

## Summary

The repo is four weeks old, so almost nothing has rotted. Most findings are
settings that were already defaults when written, plus Firefox details that
moved under the config. Worth doing first:

1. Firefox: drop the dead quickactions pref (3.1), update FirefoxSuggest to
   the Firefox 146+ meaning (3.3), fix the sidebar comment (3.2).
2. Trim settings that are now defaults (section 1). All one-liners.
3. Bump Lanzaboote to v1.2.0 and pin the CI actions (4.7, 4.8).
4. Fix the doc statements that no longer match the code (5.9 to 5.13).
5. Decide on the BlueZ Experimental flag (1.9) and, longer term, the TPM
   PCR policy (4.1).

## 1. Now the default

**1.1 systemd initrd.** [tpm_decryption.nix:47](modules/tpm_decryption.nix#L47)
(also [palantir:56](hosts/appliances/palantir/default.nix#L56),
[osse:62](hosts/appliances/osse/default.nix#L62)) sets
`boot.initrd.systemd.enable = true`. Default is `true` in 26.05; scripted
stage 1 is deprecated for 26.11. Evidence: pinned
`nixos/modules/system/boot/systemd/initrd.nix:195`,
[26.05 release notes](https://nixos.org/manual/nixos/stable/release-notes).
Hosts: nazgul, balrog, emily-laptop, jeff-laptop.

**1.2 `hardware.graphics.enable`.** [desktop.nix:36](modules/desktop.nix#L36).
`services/misc/graphical-desktop.nix` sets it `mkDefault true` whenever a
display manager is enabled. Every GNOME host.

**1.3 Bluetooth, dconf and avahi enables.**
[desktop.nix:38](modules/desktop.nix#L38),
[desktop.nix:78](modules/desktop.nix#L78),
[desktop.nix:200](modules/desktop.nix#L200). The GNOME module sets
`hardware.bluetooth.enable = mkDefault true`, `programs.dconf.enable = true`
and `services.avahi.enable = mkDefault true` (gnome.nix lines 324, 327,
414). Keep `nssmdns4` and the bluetooth `settings`.

**1.4 zram algorithm and percent.** `algorithm = "zstd"` and
`memoryPercent = 50` are the module defaults (`config/zram.nix`). Repeated in
[workstation_template.nix:63](hosts/workstation_template.nix#L63),
[balrog:31](hosts/workstations/balrog/default.nix#L31),
[nazgul:35](hosts/workstations/nazgul/default.nix#L35),
[saruman:31](hosts/workstations/saruman/default.nix#L31),
[emily-laptop:27](hosts/clients/emily-laptop/default.nix#L27),
[jeff-laptop:38](hosts/clients/jeff-laptop/default.nix#L38),
[installer:31](installer/default.nix#L31), osse, palantir. Only `enable`,
`memoryMax` and `priority` do work. See 5.2.

**1.5 autoUpgrade persistent and allowReboot.**
[maintenance.nix:29-30](modules/maintenance.nix#L29-L30). Defaults are
`true` and `false` (`tasks/auto-upgrade.nix:106,171`). All hosts.

**1.6 smartd x11 notifications.** [desktop.nix:90](modules/desktop.nix#L90).
Default is `config.services.xserver.enable`, false on the fleet. The
`wall.enable = false` line is still needed.

**1.7 `time.timeZone = mkDefault null`.**
[desktop.nix:101](modules/desktop.nix#L101). The option default is already
`null`. Keep only for the comment.

**1.8 `i18n.defaultLocale = "en_US.UTF-8"`.** NixOS default. Present in the
template, every host and the installer
([template:86](hosts/workstation_template.nix#L86),
[balrog:46](hosts/workstations/balrog/default.nix#L46),
[nazgul:50](hosts/workstations/nazgul/default.nix#L50),
[saruman:47](hosts/workstations/saruman/default.nix#L47),
[emily:49](hosts/clients/emily-laptop/default.nix#L49),
[jeff:53](hosts/clients/jeff-laptop/default.nix#L53),
[gollum:40](hosts/appliances/gollum/default.nix#L40),
[installer:47](installer/default.nix#L47)). Options: drop everywhere, or keep
in the template as the documented knob. Recommendation: drop.

**1.9 BlueZ `Experimental = true` for battery levels.**
[desktop.nix:39](modules/desktop.nix#L39). BlueZ made all Battery D-Bus
APIs non-experimental in 5.72
([commit](https://github.com/bluez/bluez/commit/495a582675cf0a4b2fee293cc215504ef24a1c43),
[release](https://github.com/bluez/bluez/releases/tag/5.72)); the fleet
has 5.86. Neither Fedora 44 nor Ubuntu 26.04 enables the flag. Removable,
but verify on a host with a BLE mouse or headset first (see 6.1).

**1.10 NetworkManager on GNOME hosts.** `networking.networkmanager.enable`
in every desktop host and the template is `mkDefault true` from the GNOME
module (gnome.nix:358). Appliances still need it. Low value; the
`networking` block stays for `hostName`.

## 2. Workarounds with an action

**2.1 Fingerprint enrolment XDG_DATA_DIRS hack: removable soon.**
[desktop.nix:119-122](modules/desktop.nix#L119-L122). nixpkgs
[issue 561267](https://github.com/NixOS/nixpkgs/issues/561267) closed
2026-10-09 via PR 571973; the backport to release-26.05,
[PR 572210](https://github.com/NixOS/nixpkgs/pull/572210), is still open.
Remove once it merges and the weekly lock bump passes it.

**2.2 `gnome50Extensions."impatience@gfxmonk.net"`: optional backport.**
[desktop.nix:182](modules/desktop.nix#L182). The manual
`gnomeExtensions.impatience` on 26.05 supports GNOME 45 to 49 only; master
has the GNOME 50 bump
([commit 378aa2a](https://github.com/NixOS/nixpkgs/commit/378aa2a),
2026-07-19) with no backport. Keep as is, or open a backport PR and switch
back afterwards.

**2.3 jeff-laptop D3cold rule comment.**
[60-amdgpu-no-d3cold.rules:17](hosts/clients/jeff-laptop/60-amdgpu-no-d3cold.rules#L17)
says "not in mainline as of kernel 7.1.x". Still absent from
[v7.2 pci.c](https://raw.githubusercontent.com/torvalds/linux/v7.2/drivers/pci/pci.c);
update to 7.2.

**2.4 palantir `allowUnfree` is unneeded.**
[palantir:119](hosts/appliances/palantir/default.nix#L119). The host
evaluates with `allowUnfree` forced to `false` (chromium, dolphin-emu and
pcsx2 are free). Remove when palantir is registered.

## 3. Stale assets

**3.1 Dead Firefox pref.** [mozilla.cfg:43](assets/firefox/mozilla.cfg#L43)
`browser.urlbar.quickactions.enabled` left firefox.js in Firefox 127
([bug 1871206](https://bugzilla.mozilla.org/show_bug.cgi?id=1871206)); no
urlbar module reads it in 157. Line 44 `browser.urlbar.suggest.quickactions`
is the live toggle. Remove line 43.

**3.2 Sidebar comment states an unsupported date.**
[mozilla.cfg:79-80](assets/firefox/mozilla.cfg#L79-L80) says the
`sidebar.revamp` pref "is removed at the end of 2027". It did default to
true in 157 (bug 2070260), but Mozilla's only published plan said
[Q3 2026](https://blog.nightly.mozilla.org/2026/01/13/phasing-out-the-older-version-of-firefox-sidebar-in-2026/),
that slipped, and no removal bug exists
([meta 1977232](https://bugzilla.mozilla.org/show_bug.cgi?id=1977232)).
Reword to "slated for removal after the 157 migration; no removal bug yet".

**3.3 FirefoxSuggest policy semantics changed in Firefox 146.**
[firefox.nix:15-19](modules/firefox.nix#L15-L19) and
[mozilla.cfg:46-51](assets/firefox/mozilla.cfg#L46-L51). In 157
`WebSuggestions` maps to `browser.urlbar.suggest.quicksuggest.all` (turns
Suggest off entirely) and a new `OnlineEnabled` key maps to
`browser.urlbar.quicksuggest.online.enabled` (default true since 146); the
`.nonsponsored` pref the cfg comments name is no longer what the policy
sets. "US only" is also out of date (157 expanded Suggest to Europe).
Options: add `OnlineEnabled = false` and update the comments, or leave it
since `.all = false` makes online moot. Recommendation: add it and fix the
comments. Evidence:
[policy-templates FirefoxSuggest](https://github.com/mozilla/policy-templates/blob/master/docs/index.md#firefoxsuggest).

**3.4 Two search-engine names never existed.**
[firefox.nix:62-63](modules/firefox.nix#L62-L63) "Perplexity AI" and
"Ask Perplexity". Every bundled search-config from 140 to 157 and the live
Remote Settings collection name the engine "Perplexity" only. Harmless;
remove.

**3.5 New-tab prefs now have a policy equivalent (taste).**
[mozilla.cfg:18-23](assets/firefox/mozilla.cfg#L18-L23). `FirefoxHome`
covers `Weather` (since 152, sets both weather prefs), `Stories` and
`SponsoredStories`; `feeds.system.topstories` and `trending.featureGate`
have no policy. The prefs still work.

**3.6 dconf keys that restate GNOME 50 or extension defaults (taste).**
Every key resolves to a real schema with a valid value. These equal the
compiled default: in both
[personal](assets/dconf/personal_environment/00-defaults) and
[client](assets/dconf/client_environment/00-defaults) files
`center-new-windows`, `night-light-schedule-automatic`, `tap-to-click`,
gtk4 `sort-directories-first`, Ptyxis `use-system-font`, blur-my-shell
`blur-original-panel`; in the personal file only, 17 dash-to-panel keys
([lines 109-144](assets/dconf/personal_environment/00-defaults#L109-L144):
appicon-style, global-border-radius, group-apps, highlight-appicon-hover,
hotkeys-overlay-combo, intellihide, panel-side-margins,
panel-top-bottom-margins, panel-top-bottom-padding, show-apps-icon-file,
stockgs-keep-dash, stockgs-keep-top-panel, trans-use-border,
trans-use-custom-bg, trans-use-custom-opacity, trans-use-dynamic-opacity,
window-preview-title-position). Keeping them pins behaviour against
upstream default changes, so this is a judgment call. The gtk3
`sort-directories-first` is not default and stays.

## 4. Upstream has moved

**4.1 TPM unlock bound to literal PCR 7 is the policy systemd stopped
recommending.** [tpm_decryption.nix:24](modules/tpm_decryption.nix#L24).
systemd 258 made the default PCR mask for new enrollments empty and
recommends systemd-pcrlock policies for PCR 7 combined with signed PCR 11;
fwupd dbx updates invalidate a literal PCR 7 seal. The explicit
`--tpm2-pcrs=7` still works on 260. Project, not a one-liner; Lanzaboote
v1.2.0 extends measured boot (4.7) but its pcrlock story was not verified
(6.4). Hosts: nazgul, balrog, emily-laptop, jeff-laptop. Evidence:
[systemd NEWS, v258](https://raw.githubusercontent.com/systemd/systemd/main/NEWS).

**4.2 chrony with NTS replaced timesyncd on Fedora and Ubuntu 26.04.**
One-liner in [desktop.nix](modules/desktop.nix)
(`services.chrony.enable = true`), every desktop host. Taste leaning stale.
Evidence:
[Ubuntu 26.04 notes](https://documentation.ubuntu.com/release-notes/26.04/summary-for-lts-users/).

**4.3 tmpfs /tmp is the default on Fedora and Ubuntu 26.04.**
[desktop.nix:50](modules/desktop.nix#L50) uses `cleanOnBoot` on disk.
One-liner (`boot.tmp.useTmpfs = true`), taste; btrfs plus zram makes disk
/tmp defensible.

**4.4 Early KMS is automatic under dracut on both distros.** Already TODO
item 2. balrog already gets `hardware.amdgpu.initrd.enable = true` from its
nixos-hardware import (`common/gpu/amd`), so the TODO's "only palantir does
it" undercounts.

**4.5 systemd-oomd placement (taste).** Fedora 44 kills on `system.slice`
and user slices at 80 percent pressure and dropped the root-slice swap
kill; the fleet targets `-.slice` and user slices
([desktop.nix:107-110](modules/desktop.nix#L107-L110)). A one-liner swap of
`enableRootSlice` for `enableSystemSlice` would mirror Fedora.

**4.6 GNOME 51 changes arriving with NixOS 26.11.** GDM 51 no longer allows
fingerprint-only login (re-auth only), so fprintd hosts will see a change;
Fedora 45 moves the keyring to oo7, for which nixpkgs has packages but no
module. Nothing to do now; a TODO note. Evidence:
[GDM NEWS](https://gitlab.gnome.org/GNOME/gdm/-/raw/main/NEWS),
[Fedora oo7 change](https://fedoraproject.org/wiki/Changes/oo7_Secrets_Service_Provider).

**4.7 Lanzaboote v1.2.0 (2026-09-26).** [flake.nix:18](flake.nix#L18) pins
v1.1.0. 1.2.0 adds PCR 4 coverage across bootloader updates (caps
`configurationLimit` at 4 only when measured boot is on, which the fleet
does not enable), a new `autoEnrollKeys.includeFirmwareBuiltinKeys`, and
removes only the internal `enrollKeys`. No rename of the options used here.
Bump plus `nix flake update lanzaboote`; secure-boot hosts. Evidence:
[release](https://github.com/nix-community/lanzaboote/releases/tag/v1.2.0).

**4.8 CI actions are behind or unpinned.**
[check.yml:24,26](.github/workflows/check.yml#L24-L26),
[update-flake-lock.yml:17,19](.github/workflows/update-flake-lock.yml#L17-L19).
`actions/checkout@v4` is three majors behind (v7.0.1, 2026-07-20).
`nix-installer-action@main` has tags (v23, 2026-09-09) and is not
deprecated, but Determinate now steers pinned CI to
`determinate-nix-action@v3`. Options: pin `checkout@v7` and
`nix-installer-action@v23`, or switch to `determinate-nix-action@v3`.
Recommendation: the first. Evidence:
[checkout releases](https://github.com/actions/checkout/releases),
[nix-installer-action tags](https://github.com/DeterminateSystems/nix-installer-action/tags).

## 5. Normalization

**5.1 Shared modules mostly use plain assignment, against the `mkDefault`
convention.** [appliance.nix](modules/appliance.nix) uses `mkDefault`
throughout; [desktop.nix](modules/desktop.nix) uses it on two lines
(consoleLogLevel, timeZone) and plain `= true` elsewhere, as do
personal_environment and parts of maintenance. A host wanting to turn off
fprintd or printing needs `mkForce`. Options: convert desktop.nix to
`mkDefault`, or amend CLAUDE.md to say plain assignment is the rule for
environment modules. Recommendation: convert.

**5.2 Identical blocks repeated across hosts.** The zram block (1.4), the
three systemd-boot lines, and the `users.users.<name>` shape appear
verbatim in five registered hosts, the template and the installer. The
fleet rule says anything two hosts share lives in `modules/`. zram and
systemd-boot could move to maintenance.nix or desktop.nix as `mkDefault`.
Counter-argument: the template is meant to be a visible menu.
Recommendation: move zram and systemd-boot; keep the user block per host.

**5.3 Same thing two ways.**
[gollum:18-24](hosts/appliances/gollum/default.nix#L18-L24) nests
`boot.loader = { ... }` while every other host writes three dotted lines.
Locale section titles drift: "Locale" (nazgul, balrog, emily, jeff), "Clock
and Locale" (saruman), "Timezone and Locale" (template, gollum, installer).

**5.4 flake.nix has no `####` banner.** [flake.nix:1](flake.nix#L1).

**5.5 dconf drift between environments.** The personal keyfile carries 38
dash-to-panel keys (panel 32, date menu centred) and the client keyfile 12
(panel 36, date menu right). If deliberate, fine; if not, one file should
be the source. Both set the same `enabled-extensions`, fonts and privacy
keys, so the 60-odd common lines could move to a shared keyfile directory
both environments list.

**5.6 `nixos-hardware` input is consumed only by the unregistered balrog.**
Idle until balrog registers; the weekly lock bump keeps fetching it.

**5.7 `boot.kernelParams = [ "quiet" ]` is set in both desktop.nix and
appliance.nix.** Harmless, but the one duplicated line between the two
shared blocks.

**5.8 installer/README.md says the ISO has CAC support.**
[installer/README.md:11-13](installer/README.md#L11-L13).
[installer/default.nix:16-17](installer/default.nix#L16-L17) imports
firefox.nix and personal_environment.nix only, not work_patch.nix. Import
work_patch or drop the claim.

**5.9 installer/README.md describes GC as "generations older than 14
days".** [installer/README.md:208-209](installer/README.md#L208-L209).
maintenance.nix runs `nix-collect-garbage` with no `--delete-older-than`
and a preStart that keeps the last 5 system generations. The next
paragraph's "the last 10 are kept" is also wrong after the first weekly GC.
Pick a number and make doc and code agree.

**5.10 CLAUDE.md says commented-out hosts are "missing hardware configs".**
[CLAUDE.md:19-20](CLAUDE.md#L19-L20). palantir has one and is commented out
as "not deployed yet"; osse and morgoth are the ones without.

**5.11 README.md says checks run on "every push and pull request".**
[README.md:37-38](README.md#L37-L38). check.yml runs on pushes to main and
non-draft PRs only, as CLAUDE.md states.

**5.12 TODO item 2 undercounts early KMS.**
[TODO.md:31-32](TODO.md#L31-L32): balrog gets amdgpu in the initrd from
nixos-hardware (4.4).

## 6. Unverified

**6.1** Whether removing BlueZ `Experimental` keeps battery levels for BLE
HID devices as well as headsets. Confirm by toggling it on nazgul and
checking Settings > Power or `upower -d`.

**6.2** Whether OpenSC
[PR 3703](https://github.com/OpenSC/OpenSC/pull/3703) (master only, not in
0.27.1) fixes the DF30 hang that
[opensc.conf:6-11](assets/cac/opensc.conf#L6-L11) describes; the upstream
thread covers a different SCE7 ATR and symptom. The `card_atr` block stays
until a release with 3703 lands and is tested.

**6.3** Whether the nazgul screenshot-key hwdb override
([nazgul:21-24](hosts/workstations/nazgul/default.nix#L21-L24)) is covered
by systemd 260's generic `pnHPEliteBook*` entries. No G10 entry exists in
`60-keyboard.hwdb`; assume still needed.

**6.4** Lanzaboote's support for systemd-pcrlock or signed PCR 11 policies,
which decides whether 4.1 is a module change or a wait.

**6.5** The four certificates in DoD bundle v5.14 that the repo omits
(ID/EMAIL CA-59, SW CA-60/61): presumably expired and pruned, not checked.
