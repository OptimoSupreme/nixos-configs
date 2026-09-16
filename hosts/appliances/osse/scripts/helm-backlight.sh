#!/bin/sh
# Bridge the Android brightness slider to the panel backlight. Waydroid's
# Android has no backlight hardware, so the slider only writes the
# screen_brightness setting (0-255); this daemon polls it via lxc-attach and
# maps it onto the host sysfs backlight. Runs as root under
# helm-backlight.service; output lands in the journal.
#
# Polling is gated on sys.boot_completed: attaching heavyweight commands
# (`settings` spawns an app_process) into the container during the
# SurfaceFlinger/hwcomposer startup window perturbs a fragile timing race in
# the ATV composer blob and can push the boot into a self-sustaining
# crash-loop. getprop is a tiny native binary and is the only thing we run
# pre-boot.

POLL=0.5      # seconds between polls once Android is booted
BOOT_POLL=10  # seconds between checks while waiting for container/boot
FLOOR_PCT=2   # never drive the panel below this % of max

# -v PATH: lxc-attach keeps the caller's environment, and a systemd service's
# PATH (nix store paths) names no directory that exists inside Android — so
# any attached command that does a PATH lookup dies with "not found".
# Absolute-path native binaries (getprop/setprop) never notice, but
# `settings` is a script whose second line runs `cmd` by bare name. Pin
# Android's own PATH (init.environ.rc) at the attach boundary; login shells
# only ever worked by luck (/bin -> /system/bin plus /bin in their PATH).
ANDROID_PATH=/product/bin:/apex/com.android.runtime/bin:/apex/com.android.art/bin:/system_ext/bin:/system/bin:/system/xbin:/odm/bin:/vendor/bin:/vendor/xbin
A() { timeout 5 lxc-attach -P /var/lib/waydroid/lxc -n waydroid -v PATH="$ANDROID_PATH" -- "$@"; }

BL=
for d in /sys/class/backlight/*/; do BL=${d%/}; done
[ -n "$BL" ] || { echo "no /sys/class/backlight device"; exit 1; }
max=$(cat "$BL/max_brightness")
floor=$((max * FLOOR_PCT / 100))
echo "bridging screen_brightness -> $BL (max=$max floor=$floor)"

booted=
last=
while :; do
    if [ -z "$booted" ]; then
        if ! lxc-info -P /var/lib/waydroid/lxc -n waydroid -s 2>/dev/null | grep -q RUNNING; then
            sleep "$BOOT_POLL"
            continue
        fi
        b=$(A /system/bin/getprop sys.boot_completed 2>/dev/null | tr -cd 01)
        if [ "$b" != 1 ]; then
            sleep "$BOOT_POLL"
            continue
        fi
        booted=1
        echo "android boot completed; starting slider polling"
    fi

    val=$(A /system/bin/settings get system screen_brightness 2>/dev/null | tr -cd 0-9)
    if [ -z "$val" ]; then
        # container went down or settings stopped answering: back to boot-wait
        echo "settings unavailable; waiting for android boot"
        booted=
        last=
        sleep "$BOOT_POLL"
        continue
    fi
    if [ "$val" != "$last" ]; then
        hw=$((val * max / 255))
        [ "$hw" -lt "$floor" ] && hw=$floor
        [ "$hw" -gt "$max" ] && hw=$max
        echo "$hw" > "$BL/brightness"
        echo "screen_brightness=$val -> brightness=$hw"
        last=$val
    fi
    sleep "$POLL"
done
