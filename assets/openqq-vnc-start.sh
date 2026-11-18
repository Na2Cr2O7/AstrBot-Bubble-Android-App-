#!/bin/bash
# Start only the VNC/noVNC part for an already-running OpenQQ display.
set -euo pipefail

OPENQQ_DISPLAY="${OPENQQ_DISPLAY:-1}"
OPENQQ_VNC_PORT="${OPENQQ_VNC_PORT:-5900}"
OPENQQ_NOVNC_PORT="${OPENQQ_NOVNC_PORT:-6080}"
OPENQQ_RUNDIR="${OPENQQ_RUNDIR:-/tmp/openqq}"

mkdir -p "$OPENQQ_RUNDIR"
export DISPLAY=":${OPENQQ_DISPLAY}"

if [ ! -S "/tmp/.X11-unix/X${OPENQQ_DISPLAY}" ]; then
  echo "Display ${DISPLAY} is not running" >&2
  exit 1
fi

if ! { [ -f "$OPENQQ_RUNDIR/x11vnc.pid" ] && kill -0 "$(cat "$OPENQQ_RUNDIR/x11vnc.pid")" 2>/dev/null; }; then
  x11vnc -display "$DISPLAY" -forever -shared -rfbport "$OPENQQ_VNC_PORT" \
    -localhost -nopw -noxdamage -noshm >"$OPENQQ_RUNDIR/x11vnc.log" 2>&1 &
  echo $! > "$OPENQQ_RUNDIR/x11vnc.pid"
fi

if ! { [ -f "$OPENQQ_RUNDIR/websockify.pid" ] && kill -0 "$(cat "$OPENQQ_RUNDIR/websockify.pid")" 2>/dev/null; }; then
  websockify --web=/usr/share/novnc/ \
    "127.0.0.1:${OPENQQ_NOVNC_PORT}" "127.0.0.1:${OPENQQ_VNC_PORT}" \
    >"$OPENQQ_RUNDIR/websockify.log" 2>&1 &
  echo $! > "$OPENQQ_RUNDIR/websockify.pid"
fi

echo "noVNC: http://127.0.0.1:${OPENQQ_NOVNC_PORT}/vnc.html?autoconnect=true"
