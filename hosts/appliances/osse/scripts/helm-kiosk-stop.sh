#!/bin/sh
# ExecStop of helm-kiosk.service: runs as the kiosk user with the unit's
# environment while weston is still alive. Graceful order matters — the
# waydroid session must stop BEFORE the compositor dies. Killing weston
# first orphans `waydroid session start`, which keeps a ghost session
# registered, and the next container boot binds to a dead compositor socket.
# systemd SIGTERMs whatever remains in the cgroup (weston, the autolaunch
# child) after this returns.
timeout 20 waydroid session stop 2>/dev/null
exit 0
