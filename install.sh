#!/bin/sh
#
# Install (or uninstall) the proxy-aware Claude/Codex/OpenCode/Pi wrappers
# WITHOUT Nix. Symlinks the command names to one core script. By default the
# commands are named `<agent>-proxy` (claude-proxy, codex-proxy, ...) so they
# never shadow the base agent binaries they launch.
#
#   curl -fsSL https://raw.githubusercontent.com/irasikhin/llm-agents-wrappers/main/install.sh | sh
#   sh install.sh [--bin-dir DIR] [--ref REF] [--suffix S | --no-suffix]
#                 [--require-proxy] [--proxy-host HOST] [--proxy-port PORT]
#   sh install.sh --uninstall [--bin-dir DIR]
#
# Options:
#   --bin-dir DIR    where the command symlinks go       (default: ~/.local/bin)
#   --ref REF        git ref to download the script from (default: main)
#   --suffix S       command suffix, e.g. --suffix proxy -> claude-proxy (default)
#   --no-suffix      install bare names (claude, codex, ...) — shadows base tools
#   --require-proxy     make a live proxy mandatory (the default; writes config)
#   --no-require-proxy  opt out of the mandatory-proxy default (writes config)
#   --proxy-host H      default proxy host  (writes the config file)
#   --proxy-port P      default proxy port  (writes the config file)
#   --uninstall      remove the symlinks (and the downloaded core script)
#   --purge          with --uninstall, also remove the config file
#   -h, --help       show this help
#
# The wrapper only LAUNCHES an agent; install the agent itself separately
# (native installer, npm or brew) — see the project README.
set -eu

REPO="irasikhin/llm-agents-wrappers"
AGENTS="claude codex opencode pi"
CORE_NAME="llm-agent-wrapper"

BIN_DIR="${BIN_DIR:-$HOME/.local/bin}"
DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/llm-wrappers"
CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/llm-wrappers/config"
REF="main"
ACTION="install"
SUFFIX="-proxy"
PURGE=0
CFG_REQUIRE=""
CFG_HOST=""
CFG_PORT=""

while [ $# -gt 0 ]; do
  case "$1" in
    --bin-dir) BIN_DIR="${2:?--bin-dir needs a value}"; shift 2 ;;
    --bin-dir=*) BIN_DIR="${1#*=}"; shift ;;
    --ref) REF="${2:?--ref needs a value}"; shift 2 ;;
    --ref=*) REF="${1#*=}"; shift ;;
    --suffix) SUFFIX="-${2:?--suffix needs a value}"; shift 2 ;;
    --suffix=*) SUFFIX="-${1#*=}" ; shift ;;
    --no-suffix) SUFFIX=""; shift ;;
    --require-proxy) CFG_REQUIRE="1"; shift ;;
    --no-require-proxy) CFG_REQUIRE="0"; shift ;;
    --proxy-host) CFG_HOST="${2:?--proxy-host needs a value}"; shift 2 ;;
    --proxy-host=*) CFG_HOST="${1#*=}"; shift ;;
    --proxy-port) CFG_PORT="${2:?--proxy-port needs a value}"; shift 2 ;;
    --proxy-port=*) CFG_PORT="${1#*=}"; shift ;;
    --uninstall) ACTION="uninstall"; shift ;;
    --purge) PURGE=1; shift ;;
    -h|--help)
      sed -n '2,/^set -eu/p' "$0" | sed 's/^# \{0,1\}//; /^set -eu/d'
      exit 0
      ;;
    *) echo "install.sh: unknown argument '$1'" >&2; exit 2 ;;
  esac
done

# Locate a core script shipped alongside this installer (checkout case).
local_core=""
case "$0" in
  */*) self_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P) ;;
  *)   self_dir="$PWD" ;;  # bare `sh install.sh` from a checkout, or curl|sh
esac
if [ -n "$self_dir" ] && [ -f "$self_dir/bin/$CORE_NAME" ]; then
  local_core="$self_dir/bin/$CORE_NAME"
fi

download() {
  _url=$1
  _out=$2
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$_url" -o "$_out"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "$_out" "$_url"
  else
    echo "install.sh: need 'curl' or 'wget' to download the wrapper" >&2
    return 1
  fi
}

# Remove a symlink only if it points at our core script.
remove_if_ours() {
  _link=$1
  if [ -L "$_link" ] && [ "$(basename "$(readlink "$_link")")" = "$CORE_NAME" ]; then
    rm -f "$_link"
    return 0
  fi
  return 1
}

if [ "$ACTION" = "uninstall" ]; then
  removed=0
  for a in $AGENTS; do
    # remove both the suffixed and bare names, if they are ours
    for name in "$a$SUFFIX" "$a" "$a-proxy"; do
      if remove_if_ours "$BIN_DIR/$name"; then
        echo "removed $BIN_DIR/$name"
        removed=$((removed + 1))
      fi
    done
  done
  if [ -f "$DATA_DIR/$CORE_NAME" ]; then
    rm -f "$DATA_DIR/$CORE_NAME"
    rmdir "$DATA_DIR" 2>/dev/null || true
  fi
  if [ "$PURGE" -eq 1 ] && [ -f "$CONFIG_FILE" ]; then
    rm -f "$CONFIG_FILE"
    echo "removed config $CONFIG_FILE"
  fi
  echo "uninstalled $removed wrapper command(s) from $BIN_DIR"
  exit 0
fi

# install: write the config file if any policy flag was given
if [ -n "$CFG_REQUIRE$CFG_HOST$CFG_PORT" ]; then
  mkdir -p "$(dirname "$CONFIG_FILE")"
  tmp_cfg=$(mktemp)
  if [ -f "$CONFIG_FILE" ]; then
    grep -vE '^(LLM_WRAPPERS_REQUIRE_PROXY|LLM_WRAPPERS_PROXY_HOST|LLM_WRAPPERS_PROXY_PORT)=' \
      "$CONFIG_FILE" > "$tmp_cfg" || true
  fi
  [ -n "$CFG_REQUIRE" ] && echo "LLM_WRAPPERS_REQUIRE_PROXY=$CFG_REQUIRE" >> "$tmp_cfg"
  [ -n "$CFG_HOST" ] && echo "LLM_WRAPPERS_PROXY_HOST=$CFG_HOST" >> "$tmp_cfg"
  [ -n "$CFG_PORT" ] && echo "LLM_WRAPPERS_PROXY_PORT=$CFG_PORT" >> "$tmp_cfg"
  mv "$tmp_cfg" "$CONFIG_FILE"
  echo "wrote policy to $CONFIG_FILE"
fi

if [ -n "$local_core" ]; then
  core="$local_core"
  echo "using checkout copy: $core"
else
  mkdir -p "$DATA_DIR"
  core="$DATA_DIR/$CORE_NAME"
  url="https://raw.githubusercontent.com/$REPO/$REF/bin/$CORE_NAME"
  echo "downloading $url"
  download "$url" "$core"
  chmod +x "$core"
fi

mkdir -p "$BIN_DIR"
for a in $AGENTS; do
  ln -sf "$core" "$BIN_DIR/$a$SUFFIX"
  echo "installed $BIN_DIR/$a$SUFFIX -> $core"
done

case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *)
    echo
    echo "note: $BIN_DIR is not on your PATH. Add it, e.g.:"
    echo "  export PATH=\"$BIN_DIR:\$PATH\""
    ;;
esac

echo
echo "done. The wrappers launch an agent but do not install it — install each"
echo "agent natively (npm / brew / native installer); see the project README."
