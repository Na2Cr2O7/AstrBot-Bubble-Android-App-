#!/bin/bash
# Stop only x11vnc/noVNC and keep Xvfb and QQ alive.
set -u

OPENQQ_DISPLAY="${OPENQQ_DISPLAY:-1}"
OPENQQ_NOVNC_PORT="${OPENQQ_NOVNC_PORT:-6080}"

pkill -f "/bin/websockify .*:${OPENQQ_NOVNC_PORT}" 2>/dev/null || true
pkill -f "x11vnc -display :${OPENQQ_DISPLAY}" 2>/dev/null || true
echo "OpenQQ VNC stopped"
