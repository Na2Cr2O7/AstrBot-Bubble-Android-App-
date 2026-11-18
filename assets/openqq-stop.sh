#!/bin/bash
# Stop OpenQQ, QQ and the virtual display started by openqq-start.sh.
set -u

OPENQQ_RUNDIR="${OPENQQ_RUNDIR:-/tmp/openqq}"
OPENQQ_DISPLAY="${OPENQQ_DISPLAY:-1}"

kill_pid_file() {
  local name="$1"
  local file="$OPENQQ_RUNDIR/${name}.pid"
  [ -f "$file" ] || return 0
  local pid
  pid="$(cat "$file" 2>/dev/null || true)"
  if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
    kill "$pid" 2>/dev/null || true
    for _ in $(seq 1 20); do
      kill -0 "$pid" 2>/dev/null || break
      sleep 0.1
    done
    if kill -0 "$pid" 2>/dev/null; then
      kill -9 "$pid" 2>/dev/null || true
    fi
  fi
  rm -f "$file"
}

# Stop the Node bridge first, then the QQ processes it launched.
kill_pid_file node
pkill -f '^/opt/QQ/qq' 2>/dev/null || true

kill_pid_file xmessage
kill_pid_file websockify
kill_pid_file x11vnc
kill_pid_file fluxbox
kill_pid_file xvfb

rm -f "/tmp/.X${OPENQQ_DISPLAY}-lock" "/tmp/.X11-unix/X${OPENQQ_DISPLAY}"
echo "OpenQQ stopped"
