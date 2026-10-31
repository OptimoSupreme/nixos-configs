# Sitrep: HDR lost over HDMI FRL on gollum

Written 2026-10-31 for whoever picks this up next. Everything below was
measured on the machine; nothing is inferred from docs alone unless marked.

## The machine

gollum is a Jovian (Steam Deck UI) appliance built from
`hosts/appliances/gollum/default.nix`, tracking `nixpkgs-unstable` with
`linuxPackages_latest`. GPU is an XFX Radeon RX 6600 (Navi 23, DIMGREY_CAVEFISH,
PCI 1002:73FF, display block DCN 3.0.2). It drives a 2021 Sony TV over HDMI.
The TV's EDID is in this directory, raw and decoded. Reach gollum over ssh;
the address and credentials are deliberately not in this repo (it is public).
Justin has them.

## What changed

Commit 2cfbb2f added `amdgpu.dcfeaturemask=0x402` to gollum's kernel params so
the driver enables HDMI 2.1 Fixed Rate Link (FRL). Bit 0x400 is `DC_FRL_MASK`,
off by default in Linux 7.2 and 7.3; 0x2 is the driver's default bit, kept
because the param replaces the mask rather than OR-ing into it. TODO.md item 4
("Drop gollum's HDMI FRL flag") covers removing it once 7.4 turns FRL on by
default.

Gollum rebuilt to generation 5 on 2026-10-30 (nixos 26.11.20261023, kernel
7.3.0) and rebooted into it.

## What was verified

All on gollum, after the reboot:

- `/proc/cmdline` carries the flag; `/sys/module/amdgpu/parameters/dcfeaturemask`
  reads 1026.
- `/sys/kernel/debug/dri/1/amdgpu_dm_dtn_log` at 3840x2160@100 shows the HPO
  (FRL) encoder active: pixel format 4:4:4, depth 10, 4 lanes, borrow mode
  ACTIVE. FRL is genuinely in use. The "Link: Training" cell in that table is
  the inverse of the LT-enable register bit and does not mean the link is
  still training.
- `drm_info` on the HDMI-A-1 connector at that mode: Colorspace=BT2020_RGB,
  HDR_OUTPUT_METADATA blob with EOTF SMPTE ST 2084, content type Game,
  Broadcast RGB Automatic, max bpc 16, vrr_capable 0. gamescope is asking for
  HDR.
- Justin pressed the TV's info button: at 4K120 (and 4K100) the TV says SDR
  and the picture is washed out. At 4K60, which is TMDS, the TV says HDR10 and
  looks right. Same session, same connector properties.

So: FRL works, the kernel thinks it is sending HDR, the TV does not receive
it. Hypothesis: the HDR static metadata infoframe is not reaching the sink on
the DCN 3.0 FRL path.

## Why 4K120 was in the menu before the flag

The EDID lists 3840x2160@120 (VIC 118) in the YCbCr 4:2:0 capability map. At
4:2:0 8-bit it fits HDMI 2.0 TMDS (594 MHz of the TV's 600 MHz limit), so
amdgpu offered the mode with or without FRL. The flag's value is the
full-quality version: 10-bit RGB 4:4:4, which needs FRL. Do not read the
mode's presence as evidence the flag works; only the DTN log tells you that.

## Ruled out

- **PCON / DisplayPort conversion.** The kernel log line "DP-HDMI FRL PCON
  supported" prints at init for any GPU whose display core can drive such a
  converter. It says nothing about what is attached. The RX 6600 has a native
  HDMI 2.1 port.
- **RGB range mismatch** (drm/amd issue 5796: full-range pixels tagged limited
  in the AVI infoframe). Kernel 7.3 contains the fixes: eb5650d1f3 "Default
  HDMI RGB output to limited range on CTA modes", 7fca7acd60 "Honor Broadcast
  RGB for BT.2020 RGB output", and the qs_bit propagation in
  `amdgpu_dm_helpers.c`. The TV's EDID has QS=1, so pixels and the Q bit agree
  (both limited). Also, a range mismatch would not flip the TV's HDR/SDR badge.
- **Missing code path.** In 7.3 `dcn30_update_info_frame()`
  (`dc/hwss/dcn30/dcn30_hwseq.c`) has an FRL branch that calls
  `hpo_frl_stream_enc->funcs->update_hdmi_info_packets()`, and
  `hpo_enc3_update_hdmi_info_packets()`
  (`dc/hpo/dcn30/dcn30_hpo_frl_stream_encoder.c`) programs `hdrsmd` into
  generic packet slot 4. `resource_build_info_frame()` builds `hdrsmd` for any
  HDMI signal including FRL. The path exists; whatever is wrong is below it
  (register programming, packet enable, or the TV not parsing the HDR
  infoframe as sent over FRL).
- **Upstream already fixed it.** As of 2026-10-31 no commit on torvalds/master
  touching the FRL stream encoder, `link_hdmi_frl.c`, `dcn30_hwseq.c` or
  `dc_resource.c` addresses HDR over FRL, and no drm/amd issue matches. The
  original out-of-tree FRL work reported HDR working, but only on an RX 9070 XT
  (RDNA4, DCN 4.0.1).

## Current decision

Justin runs gollum at 1920x1080@120 for now. That is TMDS, so HDR10 works, and
120 Hz is available. Games are capped at 1080p anyway because the RX 6600
manages 70-80 fps there. 4K120 costs HDR; 4K60 caps frames at 60 since 7.3 has
no HDMI VRR. The flag stays in the host file so the hardware is ready when the
kernel is.

## Next steps

1. Justin files `ISSUE.md` on https://gitlab.freedesktop.org/drm/amd/-/issues
   with `sony-tv.edid` attached. Nobody has posted it yet. Once filed, add the
   link to TODO.md item 4 and note that HDR over FRL is broken on DCN 3.0.2 as
   of 7.3.
2. If a maintainer asks for more data, useful things to capture at 4K120 on
   gollum: `drm.debug=0x104` around a mode set for `DC_LOG_HDMI_FRL` output,
   and the HDMI generic packet registers of the HPO stream encoder via
   `amdgpu_regs`. Neither has been collected.
3. When `linuxPackages_latest` on unstable reaches 7.4, retest 4K120 with HDR
   on before touching the flag (TODO.md item 4 then also wants VRR tried).
4. A patch to test would most likely land in
   `drivers/gpu/drm/amd/display/dc/hpo/dcn30/dcn30_hpo_frl_stream_encoder.c`.
   gollum can take a kernel override through `boot.kernelPatches` for a one-off
   test; keep it on a branch, the daily upgrade pulls main back within a day.

## Commands that answer the questions above

```
grep -o 'dcfeaturemask=[^ ]*' /proc/cmdline
cat /sys/module/amdgpu/parameters/dcfeaturemask
sudo grep -m1 -E 'mode: "[0-9]' /sys/kernel/debug/dri/1/state
sudo cat /sys/kernel/debug/dri/1/amdgpu_dm_dtn_log | grep -A2 '^HPO:'
nix shell nixpkgs#drm_info -c drm_info /dev/dri/card1
cat /sys/class/drm/card1-HDMI-A-1/edid | nix shell nixpkgs#edid-decode -c edid-decode
```

The DTN HPO table is empty when the link is TMDS. That is the quickest way to
tell which path a given mode is on.
