#!/bin/bash
# Keep the OpenQQ virtual display and VNC stack alive in its own PTY.
set -euo pipefail

OPENQQ_DISPLAY="${OPENQQ_DISPLAY:-1}"
OPENQQ_SCREEN="${OPENQQ_SCREEN:-1280x800x24}"
OPENQQ_VNC="${OPENQQ_VNC:-1}"
OPENQQ_VNC_PORT="${OPENQQ_VNC_PORT:-5900}"
OPENQQ_NOVNC_PORT="${OPENQQ_NOVNC_PORT:-6080}"
OPENQQ_DIR="${OPENQQ_DIR:-/root/OpenQQ}"
OPENQQ_CONFIG="${OPENQQ_CONFIG:-$OPENQQ_DIR/config/openqq.json}"
OPENQQ_WEB_PORT="${OPENQQ_WEB_PORT:-17860}"
READY_FILE="/tmp/openqq-display-ready"

mkdir -p /tmp/.X11-unix
chmod 1777 /tmp/.X11-unix 2>/dev/null || true
rm -f "$READY_FILE"

pkill -f "Xvfb :${OPENQQ_DISPLAY}" 2>/dev/null || true
pkill -f "x11vnc -display :${OPENQQ_DISPLAY}" 2>/dev/null || true
pkill -f 'fluxbox' 2>/dev/null || true
pkill -f "/bin/websockify .*:${OPENQQ_NOVNC_PORT}" 2>/dev/null || true
rm -f "/tmp/.X${OPENQQ_DISPLAY}-lock" "/tmp/.X11-unix/X${OPENQQ_DISPLAY}"

Xvfb ":${OPENQQ_DISPLAY}" -screen 0 "$OPENQQ_SCREEN" \
  -ac +extension GLX +render -noreset >/tmp/openqq-xvfb.log 2>&1 &
for _ in $(seq 1 50); do
  [ -S "/tmp/.X11-unix/X${OPENQQ_DISPLAY}" ] && break
  sleep 0.1
done
if [ ! -S "/tmp/.X11-unix/X${OPENQQ_DISPLAY}" ]; then
  echo "Xvfb failed to start on :${OPENQQ_DISPLAY}" >&2
  cat /tmp/openqq-xvfb.log >&2 || true
  exit 1
fi

export DISPLAY=":${OPENQQ_DISPLAY}"
if command -v fluxbox >/dev/null 2>&1; then
  fluxbox >/tmp/openqq-fluxbox.log 2>&1 &
fi

if [ "$OPENQQ_VNC" = "1" ]; then
  if command -v x11vnc >/dev/null 2>&1; then
    x11vnc -display "$DISPLAY" -forever -shared -rfbport "$OPENQQ_VNC_PORT" \
      -localhost -nopw -noxdamage -noshm >/tmp/openqq-x11vnc.log 2>&1 &
  fi
  if command -v websockify >/dev/null 2>&1 && [ -d /usr/share/novnc ]; then
    websockify --web=/usr/share/novnc/ \
      "127.0.0.1:${OPENQQ_NOVNC_PORT}" "127.0.0.1:${OPENQQ_VNC_PORT}" \
      >/tmp/openqq-websockify.log 2>&1 &
  fi
fi

echo "OpenQQ display ready: DISPLAY=$DISPLAY"
[ "$OPENQQ_VNC" = "1" ] && echo "noVNC: http://127.0.0.1:${OPENQQ_NOVNC_PORT}/vnc.html?autoconnect=true"
printf 'ready\n' > "$READY_FILE"

# Start the Node bridge in the same PTY. Keeping it as a child (instead of
# exec'ing node) avoids proot killing the session after the display setup.
export PATH="/root/.nvm/versions/node/v26.13.1/bin:$PATH"
export OPENQQ_QQ_NO_SANDBOX=1
export OPENQQ_QQ_DISABLE_GPU=1
cd "$OPENQQ_DIR"
node src/main.mjs start \
  --config "$OPENQQ_CONFIG" \
  --qq-root /opt/QQ \
  --web-port "$OPENQQ_WEB_PORT" \
  --web-host 127.0.0.1 &
NODE_PID=$!
echo "OpenQQ node pid=$NODE_PID"
wait "$NODE_PID"
