#!/bin/sh
# Runs inside weston ([autolaunch]), so WAYLAND_DISPLAY is set for us; output
# lands in the helm-kiosk journal. `waydroid session start` blocks, which is
# what keeps the session alive; `show-full-ui` only pokes the running session
# and returns. 1080p is done INSIDE waydroid (persist.waydroid.width/height,
# enforced by helm-props.service), never via live compositor scaling.
#
# The outer loop + watchdog exist because a mapped window is NOT proof of
# pixels: the ATV composer blob can lose a startup race against
# SurfaceFlinger's first present and fall into a self-sustaining crash-loop
# (SIGSEGV in get_buffer_metadata_cros; black panel, sys.boot_completed never
# sets, load pinned by restart churn). Recycling the session collapses the
# load and re-runs the race from a cold start, which converges.
#
# `waydroid prop get` is used for boot detection because this script runs as
# the kiosk user (lxc-attach needs root); it can only answer once the
# platform service is up, which is exactly the healthy-boot signal we want.
# Likewise `show-full-ui` exits 0 without any window being mapped, so its
# "ok" line is not proof of pixels either — sys.boot_completed is the only
# trustworthy check available from here.

while :; do
    echo "=== session cycle start $(date -Iseconds) WAYLAND_DISPLAY=${WAYLAND_DISPLAY:-unset} ==="

    waydroid session start &
    SESSION_PID=$!

    i=0
    while [ "$i" -lt 120 ]; do
        waydroid status 2>/dev/null | grep -qiE 'session:[[:space:]]*running' && break
        kill -0 "$SESSION_PID" 2>/dev/null || break
        i=$((i + 1))
        sleep 1
    done

    # Retry until Android is actually ready: first boots take minutes
    # (dex2oat), and a single early show-full-ui leaves the kiosk on a black
    # screen forever.
    i=0
    while [ "$i" -lt 60 ]; do
        kill -0 "$SESSION_PID" 2>/dev/null || break
        if timeout 30 waydroid show-full-ui 2>/dev/null; then
            echo "show-full-ui ok on attempt $i"
            break
        fi
        i=$((i + 1))
        sleep 5
    done

    # Watchdog: give Android 7 minutes to reach sys.boot_completed, then
    # recycle the session instead of sitting on a black panel.
    booted=
    i=0
    while [ "$i" -lt 84 ]; do
        kill -0 "$SESSION_PID" 2>/dev/null || break
        b=$(timeout 10 waydroid prop get sys.boot_completed 2>/dev/null | tr -cd 01)
        if [ "$b" = 1 ]; then
            booted=1
            break
        fi
        i=$((i + 1))
        sleep 5
    done

    if [ -z "$booted" ] && kill -0 "$SESSION_PID" 2>/dev/null; then
        echo "watchdog: sys.boot_completed not set after 7 min; recycling session $(date -Iseconds)"
        timeout 20 waydroid session stop
        kill "$SESSION_PID" 2>/dev/null
    elif [ -n "$booted" ]; then
        echo "boot completed after ${i}x5s; supervising session"
    fi

    wait "$SESSION_PID"
    echo "=== session exited $(date -Iseconds) ==="
    # brief pause so a service stop (which SIGTERMs this script's cgroup)
    # wins the race against the next cycle spawning a ghost session
    sleep 3
done
