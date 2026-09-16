#!/bin/sh
# Enforce the Waydroid persist props, every boot (idempotent):
#
#   persist.waydroid.no_presentation=true — the ATV hwcomposer's
#     wp_presentation handling SIGSEGVs SurfaceFlinger without it and boot
#     never completes
#   persist.waydroid.width/height=1920x1080 — the hwc sizes the Android
#     display as width/height x wl_output scale; these keep Android
#     compositing at a true 1080p end to end (the display side is the
#     panel's mode, /etc/helm/weston.ini)
#
# The props live in Android /data: they survive reboots but die with a /data
# wipe, which is why this converges on every boot instead of using a
# run-once marker. setprop/getprop are tiny native binaries and safe to
# attach during the boot window (unlike `settings` — see helm-backlight.sh).
# Runs as root under helm-props.service.

# -v PATH: pin Android's PATH at the attach boundary — a systemd service's
# own PATH names no directory inside Android, so attached commands that do a
# PATH lookup fail. setprop/getprop are absolute-path and don't care today;
# this keeps the helper safe for anything it's asked to run (see
# helm-backlight.sh for the failure this prevented).
ANDROID_PATH=/product/bin:/apex/com.android.runtime/bin:/apex/com.android.art/bin:/system_ext/bin:/system/bin:/system/xbin:/odm/bin:/vendor/bin:/vendor/xbin
A() { timeout 5 lxc-attach -P /var/lib/waydroid/lxc -n waydroid -v PATH="$ANDROID_PATH" -- "$@"; }

# The container comes up when the kiosk session starts; allow first boots a
# generous window.
i=0
while [ "$i" -lt 300 ]; do
    lxc-info -P /var/lib/waydroid/lxc -n waydroid -s 2>/dev/null | grep -q RUNNING && break
    i=$((i + 1)); sleep 2
done
if ! lxc-info -P /var/lib/waydroid/lxc -n waydroid -s 2>/dev/null | grep -q RUNNING; then
    echo "helm-props: container never reached RUNNING; giving up" >&2
    exit 1
fi

# The property service answers early in Android boot; retry until it does.
i=0
until A /system/bin/setprop persist.waydroid.no_presentation true 2>/dev/null; do
    i=$((i + 1))
    if [ "$i" -ge 60 ]; then
        echo "helm-props: setprop never succeeded" >&2
        exit 1
    fi
    sleep 2
done
A /system/bin/setprop persist.waydroid.width 1920
A /system/bin/setprop persist.waydroid.height 1080

echo "helm-props: no_presentation=$(A /system/bin/getprop persist.waydroid.no_presentation | tr -d '[:space:]')" \
     "size=$(A /system/bin/getprop persist.waydroid.width | tr -d '[:space:]')x$(A /system/bin/getprop persist.waydroid.height | tr -d '[:space:]')"
