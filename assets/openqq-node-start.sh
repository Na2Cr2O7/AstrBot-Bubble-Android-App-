#!/bin/bash
# Start only the OpenQQ Node bridge; the display is managed by
# openqq-display-start.sh in a separate PTY.
set -euo pipefail

OPENQQ_DIR="${OPENQQ_DIR:-/root/OpenQQ}"
OPENQQ_CONFIG="${OPENQQ_CONFIG:-$OPENQQ_DIR/config/openqq.json}"
OPENQQ_WEB_PORT="${OPENQQ_WEB_PORT:-17860}"
OPENQQ_DISPLAY="${OPENQQ_DISPLAY:-1}"

for _ in $(seq 1 100); do
  [ -S "/tmp/.X11-unix/X${OPENQQ_DISPLAY}" ] && break
  sleep 0.1
done
if [ ! -S "/tmp/.X11-unix/X${OPENQQ_DISPLAY}" ]; then
  echo "OpenQQ display :${OPENQQ_DISPLAY} is not ready" >&2
  exit 1
fi

export DISPLAY=":${OPENQQ_DISPLAY}"
NODE_VERSION="${NODE_VERSION:-26.13.1}"
export PATH="/root/.local/node-v${NODE_VERSION}/bin:/root/.nvm/versions/node/v${NODE_VERSION}/bin:/usr/local/bin:$PATH"
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
