#!/bin/bash
# OpenQQ single-user installer for the AstrBot Android Ubuntu environment.
# This script is shipped inside the APK and is intentionally independent from
# the signed AstrBot-Android-Scripts installer.
set -euo pipefail
umask 077

OPENQQ_VERSION="${OPENQQ_VERSION:-v0.3.0}"
OPENQQ_COMMIT="${OPENQQ_COMMIT:-1ccd54e}"
OPENQQ_DIR="${OPENQQ_DIR:-/root/OpenQQ}"
OPENQQ_STATE_DIR="${OPENQQ_STATE_DIR:-/root/.openqq-android}"
NODE_VERSION="${NODE_VERSION:-26.13.1}"
NVM_VERSION="${NVM_VERSION:-0.40.3}"
QQ_VERSION="${QQ_VERSION:-3.2.35-54395}"
QQ_DEB_NAME="${QQ_DEB_NAME:-QQ_3.2.35_261103_arm64_01.deb}"
QQ_DEB_URL="${QQ_DEB_URL:-https://qqdl.gtimg.cn/qqfile/QQNTV2/9.9.37/release/816b3c79/${QQ_DEB_NAME}}"
OPENQQ_WEB_PORT="${OPENQQ_WEB_PORT:-17860}"
OPENQQ_ONEBOT_PORT="${OPENQQ_ONEBOT_PORT:-6199}"
OPENQQ_ACCESS_TOKEN="${OPENQQ_ACCESS_TOKEN:-}"
OPENQQ_FORCE_REINSTALL="${OPENQQ_FORCE_REINSTALL:-0}"
TMPDIR="${TMPDIR:-/tmp}"
export TMPDIR
mkdir -p "$TMPDIR" "$OPENQQ_STATE_DIR"

log()  { printf '[openqq-install] %s\n' "$*"; }
fail() { printf '[openqq-install] ERROR: %s\n' "$*" >&2; exit 1; }

proxy_url() {
  local url="$1" proxy="${ASTRBOT_GITHUB_PROXY:-auto}"
  case "$proxy" in
    ''|direct) printf '%s\n' "$url" ;;
    https://*|http://*) printf '%s\n' "${proxy%/}/$url" ;;
    *) printf '%s\n' "https://gh-proxy.com/$url" ;;
  esac
}

curl_file() {
  local url="$1" out="$2"
  curl -fL --retry 2 --connect-timeout 20 --max-time 900 \
    -A 'openqq-android-installer' "$url" -o "$out"
}

apt_install() {
  export DEBIAN_FRONTEND=noninteractive
  apt-get -o Acquire::ForceIPv4=true update || true
  apt-get -o Acquire::ForceIPv4=true install -y --no-install-recommends "$@"
}

ensure_node() {
  local node_bin="/root/.nvm/versions/node/v${NODE_VERSION}/bin"
  if [ -x "$node_bin/node" ]; then
    export PATH="$node_bin:$PATH"
    log "Node v${NODE_VERSION} already installed"
    return 0
  fi
  log "Installing nvm ${NVM_VERSION} and Node v${NODE_VERSION}"
  local installer="$TMPDIR/nvm-install.sh"
  local raw="https://raw.githubusercontent.com/nvm-sh/nvm/v${NVM_VERSION}/install.sh"
  if ! curl_file "$(proxy_url "$raw")" "$installer"; then
    curl_file "$raw" "$installer" || fail 'could not download the nvm installer'
  fi
  bash "$installer"
  export NVM_DIR="/root/.nvm"
  # shellcheck disable=SC1091
  . "$NVM_DIR/nvm.sh"
  export NVM_NODEJS_ORG_MIRROR="${NVM_NODEJS_ORG_MIRROR:-https://npmmirror.com/mirrors/node/}"
  nvm install "$NODE_VERSION"
  nvm alias default "$NODE_VERSION" >/dev/null 2>&1 || true
  [ -x "$node_bin/node" ] || fail "Node v${NODE_VERSION} was not installed"
  export PATH="$node_bin:$PATH"
}

linuxqq_ready() {
  local version
  version="$(dpkg-query -W -f='${Version}' linuxqq 2>/dev/null || true)"
  [ "$version" = "$QQ_VERSION" ]
}

validate_linuxqq_deb() {
  local file="$1" arch package
  [ -s "$file" ] || return 1
  dpkg-deb --info "$file" >/dev/null 2>&1 || return 1
  arch="$(dpkg-deb -f "$file" Architecture 2>/dev/null)"
  package="$(dpkg-deb -f "$file" Package 2>/dev/null)"
  version="$(dpkg-deb -f "$file" Version 2>/dev/null)"
  case "$arch" in arm64|aarch64) ;; *) return 1 ;; esac
  [ "$package" = "linuxqq" ] || return 1
  [ "$version" = "$QQ_VERSION" ]
}

get_linuxqq_signed_url() {
  local bare_url="$1"
  local api_url="https://im.qq.com/http2rpc/gotrpc/noauth/trpc.qqntv2.urlsign.UrlSign/GetSign"
  local response_file="$TMPDIR/linuxqq-sign.json"
  local normalized_file="$TMPDIR/linuxqq-sign-normalized.json"
  local payload
  LINUXQQ_SIGNED_URL=""
  payload="$(printf '{"url":"%s"}' "$bare_url")"
  log "Requesting a signed LinuxQQ download URL"
  curl -fL --connect-timeout 15 --max-time 30 \
    -A 'Mozilla/5.0 (X11; Linux aarch64) AppleWebKit/537.36 Chrome/124 Safari/537.36' \
    -e 'https://im.qq.com/' \
    -H 'Accept: application/json, text/plain, */*' \
    -H 'Content-Type: application/json' \
    -H 'x-oidb: {"uint32_command":"0x9b8e","uint32_service_type":1}' \
    --data "$payload" "$api_url" -o "$response_file" || return 1
  sed 's#\\/#/#g; s#\\u0026#\&#g; s#\\u003d#=#g' "$response_file" > "$normalized_file"
  LINUXQQ_SIGNED_URL="$(grep -Eo '"url"[[:space:]]*:[[:space:]]*"[^"]+"' "$normalized_file" |
    head -n 1 | sed -E 's/^"url"[[:space:]]*:[[:space:]]*"//; s/"$//')"
  case "$LINUXQQ_SIGNED_URL" in
    https://*.deb|https://*.deb\?*) return 0 ;;
    *) LINUXQQ_SIGNED_URL=""; return 1 ;;
  esac
}

download_linuxqq() {
  local dest="$1" part="${dest}.part" candidate
  for candidate in \
    "${ASTRBOT_LINUXQQ_FILE:-}" \
    "/root/${QQ_DEB_NAME}" \
    "/sdcard/Download/${QQ_DEB_NAME}" \
    "/storage/emulated/0/Download/${QQ_DEB_NAME}"; do
    [ -n "$candidate" ] && [ -f "$candidate" ] || continue
    if validate_linuxqq_deb "$candidate"; then
      log "Using local LinuxQQ package: $candidate"
      cp -f "$candidate" "$dest"
      return 0
    fi
  done

  rm -f "$part"
  if ! curl_file "$QQ_DEB_URL" "$part"; then
    log "Direct LinuxQQ URL failed; trying signed URL"
    get_linuxqq_signed_url "$QQ_DEB_URL" || return 1
    curl_file "$LINUXQQ_SIGNED_URL" "$part" || return 1
  fi
  validate_linuxqq_deb "$part" || { rm -f "$part"; return 1; }
  mv -f "$part" "$dest"
}

ensure_linuxqq() {
  if linuxqq_ready; then
    log "LinuxQQ ${QQ_VERSION} already installed"
    return 0
  fi
  local deb="/root/${QQ_DEB_NAME}"
  if ! validate_linuxqq_deb "$deb"; then
    rm -f "$deb"
    download_linuxqq "$deb" || fail 'could not download the pinned LinuxQQ package'
  fi
  validate_linuxqq_deb "$deb" || fail 'LinuxQQ package validation failed'
  log "Installing LinuxQQ ${QQ_VERSION}"
  local sound_package
  if apt-cache show libasound2t64 >/dev/null 2>&1; then
    sound_package=libasound2t64
  else
    sound_package=libasound2
  fi
  apt_install libnss3 libgbm1 libnspr4 "$sound_package"
  apt-get install -y --allow-downgrades "$deb" || {
    apt-get -f install -y
    apt-get install -y --allow-downgrades "$deb"
  }
  linuxqq_ready || fail 'LinuxQQ installation did not reach the pinned version'
}

write_config_if_missing() {
  local config="$OPENQQ_DIR/config/openqq.json"
  [ -f "$config" ] && return 0
  mkdir -p "$OPENQQ_DIR/config" "$OPENQQ_DIR/data"
  OPENQQ_ACCESS_TOKEN="${OPENQQ_ACCESS_TOKEN:-$(openssl rand -hex 32)}"
  OPENQQ_ACCESS_TOKEN="$OPENQQ_ACCESS_TOKEN" \
  OPENQQ_WEB_PORT="$OPENQQ_WEB_PORT" \
  OPENQQ_ONEBOT_PORT="$OPENQQ_ONEBOT_PORT" \
  python3 - "$config" <<'PY'
import json, os, sys
cfg = {
    "version": 1,
    "qqRoot": "/opt/QQ",
    "webPort": int(os.environ["OPENQQ_WEB_PORT"]),
    "accessToken": os.environ["OPENQQ_ACCESS_TOKEN"],
    "ws": {"enabled": False, "host": "127.0.0.1", "port": 3001},
    "reverseWs": [{
        "enabled": True,
        "url": f"ws://127.0.0.1:{os.environ['OPENQQ_ONEBOT_PORT']}/ws",
        "token": "",
    }],
}
with open(sys.argv[1], "w", encoding="utf-8") as f:
    json.dump(cfg, f, ensure_ascii=False, indent=2)
    f.write("\n")
PY
  chmod 600 "$config"
}

install_openqq() {
  local marker="$OPENQQ_STATE_DIR/installed.json"
  if [ "$OPENQQ_FORCE_REINSTALL" != "1" ] && [ -f "$marker" ] && [ -d "$OPENQQ_DIR/.git" ]; then
    if python3 - "$marker" "$OPENQQ_VERSION" "$NODE_VERSION" "$QQ_VERSION" <<'PY'
import json, sys
try:
    d = json.load(open(sys.argv[1], encoding="utf-8"))
except Exception:
    raise SystemExit(1)
raise SystemExit(0 if d.get("openqq") == sys.argv[2] and d.get("node") == sys.argv[3] and d.get("qq") == sys.argv[4] else 1)
PY
    then
      log "OpenQQ ${OPENQQ_VERSION} is already installed"
      printf '__OPENQQ_ALREADY_INSTALLED__\n'
      printf '__OPENQQ_INSTALL_DONE__\n'
      return 0
    fi
  fi

  local backup="$OPENQQ_STATE_DIR/backup"
  rm -rf "$backup"
  mkdir -p "$backup"
  if [ -f "$OPENQQ_DIR/config/openqq.json" ]; then
    mkdir -p "$backup/config"
    cp -a "$OPENQQ_DIR/config/openqq.json" "$backup/config/"
  fi
  if [ -d "$OPENQQ_DIR/data" ]; then
    cp -a "$OPENQQ_DIR/data" "$backup/data"
  fi

  rm -rf "$OPENQQ_DIR"
  log "Cloning OpenQQ ${OPENQQ_VERSION}"
  local repo="https://github.com/feijx3/OpenQQ.git"
  if ! git clone --branch "$OPENQQ_VERSION" --depth 1 "$(proxy_url "$repo")" "$OPENQQ_DIR"; then
    git clone --branch "$OPENQQ_VERSION" --depth 1 "$repo" "$OPENQQ_DIR" ||
      fail 'could not clone OpenQQ'
  fi
  git -C "$OPENQQ_DIR" checkout --detach "$OPENQQ_COMMIT" >/dev/null 2>&1 || true

  if [ -d "$backup/config" ]; then
    mkdir -p "$OPENQQ_DIR/config"
    cp -a "$backup/config/openqq.json" "$OPENQQ_DIR/config/"
  fi
  if [ -d "$backup/data" ]; then
    cp -a "$backup/data" "$OPENQQ_DIR/data"
  fi
  mkdir -p "$OPENQQ_DIR/data"

  python3 - "$OPENQQ_DIR/package.json" <<'PY'
import json, sys
p = sys.argv[1]
d = json.load(open(p, encoding="utf-8"))
d["allowScripts"] = {"@parcel/watcher@2.6.0": True, "esbuild@0.28.2": True}
json.dump(d, open(p, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
PY

  export PATH="/root/.nvm/versions/node/v${NODE_VERSION}/bin:$PATH"
  npm config set registry https://registry.npmmirror.com >/dev/null 2>&1 || true
  log "Installing OpenQQ dependencies with Node $(node -v)"
  (cd "$OPENQQ_DIR" && npm ci --no-audit --no-fund)
  log "Building OpenQQ"
  (cd "$OPENQQ_DIR" && npm run build)
  log "Pruning OpenQQ dev dependencies"
  (cd "$OPENQQ_DIR" && npm prune --omit=dev)
  write_config_if_missing

  python3 - "$marker" "$OPENQQ_VERSION" "$NODE_VERSION" "$QQ_VERSION" <<'PY'
import json, sys, time
json.dump({
    "openqq": sys.argv[2],
    "node": sys.argv[3],
    "qq": sys.argv[4],
    "installedAt": int(time.time()),
}, open(sys.argv[1], "w", encoding="utf-8"), ensure_ascii=False, indent=2)
PY
  chmod 600 "$marker"
  log "OpenQQ ${OPENQQ_VERSION} installed"
  printf '__OPENQQ_INSTALL_DONE__\n'
}

main() {
  log "Installing OpenQQ ${OPENQQ_VERSION}; Node ${NODE_VERSION}; QQ ${QQ_VERSION}"
  apt_install ca-certificates curl git sudo openssl python3 xvfb fluxbox \
    x11vnc novnc websockify xauth x11-utils fonts-wqy-zenhei \
    cmake g++ make ninja-build
  ensure_node
  ensure_linuxqq
  install_openqq
}

main "$@"
