#!/bin/sh
# Helm kiosk session: weston kiosk-shell. helm-kiosk.service runs this as the
# kiosk user and owns respawn — this script must exec weston, not loop.
# --debug authorizes weston-screenshooter, which is how the panel is verified
# over ssh without eyes on it.
#
# The lingering user@ manager provides two things waydroid's session hard-
# requires: the session bus at $XDG_RUNTIME_DIR/bus, and the pulse socket —
# $XDG_RUNTIME_DIR/pulse/native is bind-mounted into the container, and with
# no socket the container cannot start at all. The bus is there by the time
# the unit orders after user@1000; the pulse socket is socket-activated, so
# wait for it rather than race it.
i=0
while [ "$i" -lt 15 ] && [ ! -S "$XDG_RUNTIME_DIR/pulse/native" ]; do
    i=$((i + 1)); sleep 1
done
[ -S "$XDG_RUNTIME_DIR/pulse/native" ] || \
    echo "helm-session: no pulse socket at $XDG_RUNTIME_DIR/pulse/native; the waydroid container may refuse to start"

export LIBSEAT_BACKEND=seatd

# Tear-free presentation: weston 15 lifts the fullscreen Waydroid dmabuf onto
# a DRM overlay plane (direct scanout of the client buffer). The ATV
# hwcomposer neither uses explicit sync nor holds buffers back until
# wl_buffer.release, so Android re-renders into a buffer that is still on the
# plane — visible as screen tearing during motion. Forcing everything through
# the GL renderer restores the tear-free path: weston's own framebuffer flips
# at vsync and its sampling of the client buffer is implicitly fenced. Cost
# is one 1080p composite pass per frame on the GPU.
export WESTON_FORCE_RENDERER=1

# helm's lab box also waited here for its eDP connector (weston started
# before i915 bound grabbed the transient simpledrm framebuffer and crashed
# when the real driver took over) and picked the panel's card by hand on a
# two-GPU box. Neither is here: weston takes the boot VGA device, and a lost
# race costs one Restart=always cycle. Bring them back if a real box needs
# them (README, "Hardware profile").
exec weston --debug --config=/etc/helm/weston.ini
