#!/bin/sh
# First-boot Android init, run once by helm-firstboot.service before the
# container and the kiosk start. The system/vendor images are baked into the
# system at /etc/waydroid-extra/images (a store path — one of waydroid's
# preinstalled-image paths), so init is offline and takes seconds, and OTA is
# disabled. The -c/-v channels below only matter as a fallback if the baked
# images ever go missing; that path needs network and downloads ~1.6 GB.
set -e

# waydroid init snapshots /dev/dri to choose between the GPU stack and
# swiftshader, and on a cold boot the GPU driver can bind seconds after this
# unit starts — an unguarded init bakes ro.hardware.egl=swiftshader into the
# props and Android crash-loops on the resulting buffers. Wait, bounded: a
# GPU that never binds costs 30 s, not the boot. (This is the one
# hardware-agnostic piece of helm's GPU handling; pinning Waydroid to the
# display GPU of its two-GPU lab box stayed behind — README.)
i=0
while [ "$i" -lt 30 ]; do
    set -- /dev/dri/renderD*
    [ -e "$1" ] && break
    i=$((i + 1)); sleep 1
done

echo "helm: first-time setup — initializing the Android runtime..." > /dev/console 2>/dev/null || true

waydroid init -f -r lineage -s GAPPS \
    -c https://waydroid-atv.github.io/ota/a16-qpr2/system \
    -v https://waydroid-atv.github.io/ota/a16-qpr2/vendor

echo "helm: Android initialized; the first boot spends a few minutes optimizing before the chart appears." > /dev/console 2>/dev/null || true
