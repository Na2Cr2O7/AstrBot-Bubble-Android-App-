#!/bin/bash
# Stop OpenQQ, QQ and the virtual display. PID files are deliberately not
# used because guest PIDs differ across proot sessions.
set -u

OPENQQ_DISPLAY="${OPENQQ_DISPLAY:-1}"
OPENQQ_NOVNC_PORT="${OPENQQ_NOVNC_PORT:-6080}"

pkill -f 'openqq-node-start.sh' 2>/dev/null || true
pkill -f 'openqq-display-start.sh' 2>/dev/null || true
pkill -f 'node src/main\.mjs' 2>/dev/null || true
pkill -f '/opt/QQ/qq' 2>/dev/null || true
pkill -f 'x11vnc -display :'"$OPENQQ_DISPLAY" 2>/dev/null || true
pkill -f '/bin/websockify .*:'"$OPENQQ_NOVNC_PORT" 2>/dev/null || true
pkill -f 'fluxbox' 2>/dev/null || true
pkill -f 'Xvfb :'"$OPENQQ_DISPLAY" 2>/dev/null || true

rm -f "/tmp/.X${OPENQQ_DISPLAY}-lock" "/tmp/.X11-unix/X${OPENQQ_DISPLAY}"
echo "OpenQQ stopped"
