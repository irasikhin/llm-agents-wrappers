#!/bin/sh
#
# Install (or uninstall) the proxy-aware Claude/Codex/OpenCode/Pi wrappers
# WITHOUT Nix. Symlinks the four command names to one core script.
#
#   curl -fsSL https://raw.githubusercontent.com/irasikhin/llm-agents-wrappers/main/install.sh | sh
#   sh install.sh [--bin-dir DIR] [--ref REF]
#   sh install.sh --uninstall [--bin-dir DIR]
#
# Options:
#   --bin-dir DIR   where the command symlinks go      (default: ~/.local/bin)
#   --ref REF       git ref to download the script from (default: main)
#   --uninstall     remove the symlinks (and the downloaded core script)
#   -h, --help      show this help
#
# The wrapper only LAUNCHES an agent; install the agent itself separately
# (native installer, npm or brew) — see the project README.
set -eu

REPO="irasikhin/llm-agents-wrappers"
AGENTS="claude codex opencode pi"
CORE_NAME="llm-agent-wrapper"

BIN_DIR="${BIN_DIR:-$HOME/.local/bin}"
DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/llm-wrappers"
REF="main"
ACTION="install"

while [ $# -gt 0 ]; do
  case "$1" in
    --bin-dir) BIN_DIR="${2:?--bin-dir needs a value}"; shift 2 ;;
    --bin-dir=*) BIN_DIR="${1#*=}"; shift ;;
    --ref) REF="${2:?--ref needs a value}"; shift 2 ;;
    --ref=*) REF="${1#*=}"; shift ;;
    --uninstall) ACTION="uninstall"; shift ;;
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

if [ "$ACTION" = "uninstall" ]; then
  removed=0
  for a in $AGENTS; do
    link="$BIN_DIR/$a"
    if [ -L "$link" ]; then
      target=$(readlink "$link")
      if [ "$(basename "$target")" = "$CORE_NAME" ]; then
        rm -f "$link"
        removed=$((removed + 1))
      fi
    fi
  done
  if [ -f "$DATA_DIR/$CORE_NAME" ]; then
    rm -f "$DATA_DIR/$CORE_NAME"
    rmdir "$DATA_DIR" 2>/dev/null || true
  fi
  echo "uninstalled $removed wrapper command(s) from $BIN_DIR"
  exit 0
fi

# install
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
  ln -sf "$core" "$BIN_DIR/$a"
  echo "installed $BIN_DIR/$a -> $core"
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
