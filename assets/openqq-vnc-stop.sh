#!/bin/bash
# Stop only x11vnc and websockify, keeping Xvfb and QQ alive.
set -u

OPENQQ_RUNDIR="${OPENQQ_RUNDIR:-/tmp/openqq}"

kill_pid_file() {
  local name="$1"
  local file="$OPENQQ_RUNDIR/${name}.pid"
  [ -f "$file" ] || return 0
  local pid
  pid="$(cat "$file" 2>/dev/null || true)"
  if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
    kill "$pid" 2>/dev/null || true
  fi
  rm -f "$file"
}

kill_pid_file websockify
kill_pid_file x11vnc
echo "OpenQQ VNC stopped"
