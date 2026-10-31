Title: HDMI FRL on DCN 3.0.2 (Navi 23): TV reports SDR while HDR_OUTPUT_METADATA is set; same stream over TMDS is HDR

## Summary

With FRL enabled (`amdgpu.dcfeaturemask=0x402`) an RX 6600 drives a Sony TV at 3840x2160@120 RGB 10 bpc over FRL, but the TV stays in SDR. The compositor has HDR_OUTPUT_METADATA (PQ) and Colorspace=BT2020_RGB set on the connector, so the picture comes out washed out. Switching to 3840x2160@60, where the link is TMDS, the TV reports HDR10 with the same connector state. Looks like the HDR static metadata infoframe is not reaching the sink on the DCN 3.0 FRL path.

## Environment

- GPU: XFX Radeon RX 6600, Navi 23 / DIMGREY_CAVEFISH, PCI 1002:73FF (1EAE:6505), DCN 3.0.2
- Kernel 7.3.0 (NixOS unstable), Display Core v3.2.392, `amdgpu.dcfeaturemask=0x402`
- Sink: Sony TV, 2021, EDID attached. HF-VSDB: FRL up to 12 Gbps x4, QS=1, VRR 48-120
- Client: gamescope (Steam Deck UI session), HDR enabled

## Steps

1. Boot with `amdgpu.dcfeaturemask=0x402`.
2. In gamescope with HDR on, select 3840x2160@120 (or @100).
3. Press the info button on the TV.

## Observed

TV info banner says SDR, picture is washed out. `amdgpu_dm_dtn_log` confirms the FRL link is up:

```
HPO:   OTG Inst     Link   Pixel Format   Depth   ODM Segments   Lanes   Borrow   h_active   h_blank
[0]:          0   Training        4:4:4      10              1       4   ACTIVE       3840      1440
```

Connector properties at that point (drm_info):

```
"Colorspace" = BT2020_RGB
"HDR_OUTPUT_METADATA": blob, EOTF: SMPTE ST 2084 (PQ)
"Broadcast RGB" = Automatic
"content type" = Game
"max bpc" = 16
```

## Expected

TV enters HDR10 at 4K120 over FRL like it does at 4K60 over TMDS.

## Notes

- `dcn30_update_info_frame()` does have an FRL branch calling `hpo_frl_stream_enc->funcs->update_hdmi_info_packets()`, and `hpo_enc3_update_hdmi_info_packets()` puts `hdrsmd` on generic packet 4, so the path exists; whatever is missing is below that.
- Not a range issue: 7.3 has eb5650d1f3 and the sink has QS=1, so pixels and the AVI Q bit are both limited.
- Happy to test patches or pull more debug output.
