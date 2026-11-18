#!/bin/bash
# Start the single-user OpenQQ instance and its virtual display.
set -euo pipefail

OPENQQ_DIR="${OPENQQ_DIR:-/root/OpenQQ}"
OPENQQ_CONFIG="${OPENQQ_CONFIG:-$OPENQQ_DIR/config/openqq.json}"
OPENQQ_WEB_PORT="${OPENQQ_WEB_PORT:-17860}"
OPENQQ_DISPLAY="${OPENQQ_DISPLAY:-1}"
OPENQQ_SCREEN="${OPENQQ_SCREEN:-1280x800x24}"
OPENQQ_VNC="${OPENQQ_VNC:-1}"
OPENQQ_VNC_PORT="${OPENQQ_VNC_PORT:-5900}"
OPENQQ_NOVNC_PORT="${OPENQQ_NOVNC_PORT:-6080}"
OPENQQ_RUNDIR="${OPENQQ_RUNDIR:-/tmp/openqq}"

mkdir -p "$OPENQQ_RUNDIR" /tmp/.X11-unix
chmod 1777 /tmp/.X11-unix 2>/dev/null || true

if [ -f "$OPENQQ_RUNDIR/node.pid" ] && kill -0 "$(cat "$OPENQQ_RUNDIR/node.pid")" 2>/dev/null; then
  echo "OpenQQ is already running (PID $(cat "$OPENQQ_RUNDIR/node.pid"))"
  exit 0
fi

kill_pid_file() {
  local file="$1"
  [ -f "$file" ] || return 0
  local pid
  pid="$(cat "$file" 2>/dev/null || true)"
  if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
    kill "$pid" 2>/dev/null || true
  fi
  rm -f "$file"
}

for name in xmessage websockify x11vnc fluxbox xvfb; do
  kill_pid_file "$OPENQQ_RUNDIR/$name.pid"
done
rm -f "/tmp/.X${OPENQQ_DISPLAY}-lock" "/tmp/.X11-unix/X${OPENQQ_DISPLAY}"

Xvfb ":${OPENQQ_DISPLAY}" -screen 0 "$OPENQQ_SCREEN" \
  -ac +extension GLX +render -noreset >"$OPENQQ_RUNDIR/xvfb.log" 2>&1 &
echo $! > "$OPENQQ_RUNDIR/xvfb.pid"
for _ in $(seq 1 50); do
  [ -S "/tmp/.X11-unix/X${OPENQQ_DISPLAY}" ] && break
  sleep 0.1
done
if [ ! -S "/tmp/.X11-unix/X${OPENQQ_DISPLAY}" ]; then
  echo "Xvfb failed to start on :${OPENQQ_DISPLAY}" >&2
  cat "$OPENQQ_RUNDIR/xvfb.log" >&2 || true
  exit 1
fi

export DISPLAY=":${OPENQQ_DISPLAY}"
if command -v fluxbox >/dev/null 2>&1; then
  fluxbox >"$OPENQQ_RUNDIR/fluxbox.log" 2>&1 &
  echo $! > "$OPENQQ_RUNDIR/fluxbox.pid"
fi

if [ "$OPENQQ_VNC" = "1" ]; then
  if command -v x11vnc >/dev/null 2>&1; then
    x11vnc -display "$DISPLAY" -forever -shared -rfbport "$OPENQQ_VNC_PORT" \
      -localhost -nopw -noxdamage -noshm >"$OPENQQ_RUNDIR/x11vnc.log" 2>&1 &
    echo $! > "$OPENQQ_RUNDIR/x11vnc.pid"
  fi
  if command -v websockify >/dev/null 2>&1 && [ -d /usr/share/novnc ]; then
    websockify --web=/usr/share/novnc/ \
      "127.0.0.1:${OPENQQ_NOVNC_PORT}" "127.0.0.1:${OPENQQ_VNC_PORT}" \
      >"$OPENQQ_RUNDIR/websockify.log" 2>&1 &
    echo $! > "$OPENQQ_RUNDIR/websockify.pid"
  fi
fi

export PATH="/root/.nvm/versions/node/v26.13.1/bin:$PATH"
export OPENQQ_QQ_NO_SANDBOX=1
export OPENQQ_QQ_DISABLE_GPU=1

echo "OpenQQ starting: DISPLAY=$DISPLAY WebUI=http://127.0.0.1:${OPENQQ_WEB_PORT}"
if [ "$OPENQQ_VNC" = "1" ]; then
  echo "noVNC: http://127.0.0.1:${OPENQQ_NOVNC_PORT}/vnc.html?autoconnect=true"
fi

cd "$OPENQQ_DIR"
echo $$ > "$OPENQQ_RUNDIR/node.pid"
exec node src/main.mjs start \
  --config "$OPENQQ_CONFIG" \
  --qq-root /opt/QQ \
  --web-port "$OPENQQ_WEB_PORT" \
  --web-host 127.0.0.1
