#!/bin/bash
# Start only x11vnc/noVNC for an already-running OpenQQ display.
set -euo pipefail

OPENQQ_DISPLAY="${OPENQQ_DISPLAY:-1}"
OPENQQ_VNC_PORT="${OPENQQ_VNC_PORT:-5900}"
OPENQQ_NOVNC_PORT="${OPENQQ_NOVNC_PORT:-6080}"

export DISPLAY=":${OPENQQ_DISPLAY}"
if [ ! -S "/tmp/.X11-unix/X${OPENQQ_DISPLAY}" ]; then
  echo "Display ${DISPLAY} is not running" >&2
  exit 1
fi

if ! pgrep -f "x11vnc -display :${OPENQQ_DISPLAY}" >/dev/null 2>&1; then
  x11vnc -display "$DISPLAY" -forever -shared -rfbport "$OPENQQ_VNC_PORT" \
    -localhost -nopw -noxdamage -noshm >/tmp/openqq-x11vnc.log 2>&1 &
fi
if ! pgrep -f "/bin/websockify .*:${OPENQQ_NOVNC_PORT}" >/dev/null 2>&1; then
  websockify --web=/usr/share/novnc/ \
    "127.0.0.1:${OPENQQ_NOVNC_PORT}" "127.0.0.1:${OPENQQ_VNC_PORT}" \
    >/tmp/openqq-websockify.log 2>&1 &
fi

echo "noVNC: http://127.0.0.1:${OPENQQ_NOVNC_PORT}/vnc.html?autoconnect=true"
