#!/bin/sh
# Oxrion dispatcher installer — https://get.oxrion.com
#
#   curl -fsSL https://get.oxrion.com | sh
#
# This installs ONLY the `oxrion` dispatcher: a tiny launcher that, on first
# use of a tool, reads https://get.oxrion.com/manifest.json and downloads the
# real tool (recovery, licenser, …) into ~/.oxrion/bin. This script itself is
# deliberately dumb — it fetches one binary, drops it in ~/.oxrion/bin, and puts
# that dir on PATH. Everything else is the dispatcher's job.
#
# It is idempotent: re-running it just reinstalls the latest dispatcher.
set -eu

REPO="oxrion/dispatcher-releases"
BASE="https://github.com/${REPO}/releases/latest/download"
BIN_DIR="${HOME}/.oxrion/bin"
DISPATCHER="${BIN_DIR}/oxrion"

info()  { printf '%s\n' "$*"; }
warn()  { printf '%s\n' "$*" >&2; }
die()   { printf 'error: %s\n' "$*" >&2; exit 1; }

# --- refuse management verbs on the pipe (get = install only) ---------------
# `curl get.oxrion.com | sh -s -- uninstall` would be surprising: the "get"
# gate only installs. Management lives in the installed `oxrion` command.
for arg in "$@"; do
  case "$arg" in
    uninstall|remove|update|upgrade|verify|info)
      die "The install gate only installs. Run 'oxrion $arg' with the installed command instead."
      ;;
  esac
done

# --- detect platform -> manifest artifact key -------------------------------
os="$(uname -s)"
arch="$(uname -m)"

case "$os" in
  Linux)  plat="linux" ;;
  Darwin) plat="macos" ;;
  *) die "Unsupported OS: $os. Oxrion supports Linux, macOS, and Windows (use the PowerShell installer on Windows)." ;;
esac

case "$arch" in
  x86_64|amd64) cpu="x64" ;;
  arm64|aarch64) cpu="arm64" ;;
  *) die "Unsupported architecture: $arch." ;;
esac

# Linux ships x64 only; macOS ships x64 + arm64. Match the build matrix.
if [ "$plat" = "linux" ] && [ "$cpu" != "x64" ]; then
  die "Linux builds are x64 only right now (found $arch)."
fi

asset="oxrion-${plat}-${cpu}"
url="${BASE}/${asset}"

# --- pick a downloader ------------------------------------------------------
if command -v curl >/dev/null 2>&1; then
  fetch() { curl -fSL "$1" -o "$2"; }
elif command -v wget >/dev/null 2>&1; then
  fetch() { wget -qO "$2" "$1"; }
else
  die "Neither curl nor wget is available. Install one and re-run."
fi

info "Installing the Oxrion dispatcher ($asset)…"
mkdir -p "$BIN_DIR"

# Download to a temp file, then move into place atomically, so an interrupted
# download can never leave a half-written binary that later runs.
tmp="$(mktemp "${BIN_DIR}/.oxrion.XXXXXX")" || die "Could not create a temp file in $BIN_DIR."
trap 'rm -f "$tmp"' EXIT INT TERM

fetch "$url" "$tmp" || die "Download failed: $url"

# Basic sanity: a GitHub 404 page is small HTML, not a multi-MB binary.
if [ ! -s "$tmp" ]; then
  die "Downloaded file is empty. The release may be missing $asset."
fi

chmod +x "$tmp"
mv -f "$tmp" "$DISPATCHER"
trap - EXIT INT TERM

info "Installed: $DISPATCHER"

# --- put ~/.oxrion/bin on PATH ----------------------------------------------
# Only append if it isn't already resolvable, and only to a shell rc we can
# find. We never edit system files.
add_path_line='export PATH="$HOME/.oxrion/bin:$PATH"'

already_on_path() {
  case ":${PATH}:" in
    *":${BIN_DIR}:"*) return 0 ;;
    *) return 1 ;;
  esac
}

ensure_path() {
  # Choose an rc file based on the login shell; fall back to .profile.
  shell_name="$(basename "${SHELL:-sh}")"
  case "$shell_name" in
    zsh)  rc="${HOME}/.zshrc" ;;
    bash) rc="${HOME}/.bashrc" ;;
    *)    rc="${HOME}/.profile" ;;
  esac

  if [ -f "$rc" ] && grep -Fq ".oxrion/bin" "$rc" 2>/dev/null; then
    return 0  # already added on a previous run
  fi

  {
    printf '\n# Added by the Oxrion installer\n%s\n' "$add_path_line"
  } >> "$rc" 2>/dev/null || { warn "Could not update $rc automatically."; return 1; }

  info "Added ~/.oxrion/bin to PATH in $rc"
  info "Open a new terminal, or run:  ${add_path_line}"
}

if already_on_path; then
  info "~/.oxrion/bin is already on your PATH."
else
  ensure_path || {
    warn "Add this line to your shell profile to use 'oxrion' everywhere:"
    warn "  $add_path_line"
  }
fi

info ""
info "Done. Try:  oxrion --help"
info "The first time you run a tool (e.g. 'oxrion recovery'), it downloads that tool automatically."
