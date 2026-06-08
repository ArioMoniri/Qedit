#!/usr/bin/env bash
#
# Qedit + ChangeX — one-command suite installer (macOS / Linux).
#
#   macOS : installs Qedit (find + edit any file, Quick Look previews) AND ChangeX
#           (tracked-changes + preview engine), then turns ON both Quick Look previews.
#   Linux : installs ChangeX only — Qedit is a macOS app (its editor uses macOS-only
#           Quick Look / AppKit APIs) and has no Linux/Windows build.
#
# Run it with:
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/ArioMoniri/Qedit/main/scripts/install.sh)"
#
# It only uses Homebrew (for Qedit) and uv/pipx/pip (for ChangeX) — nothing else is downloaded
# or executed. Read it first if you like; it's intentionally short and boring.

set -euo pipefail

say()  { printf '\033[1;34m▸ %s\033[0m\n' "$*"; }
ok()   { printf '\033[1;32m✓ %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m! %s\033[0m\n' "$*"; }

install_changex() {
  say "Installing ChangeX (cross-platform tracked-changes + preview engine)…"
  if command -v uv >/dev/null 2>&1; then
    uv tool install --upgrade "changex[preview]" 2>/dev/null || uv tool install --upgrade changex
  elif command -v pipx >/dev/null 2>&1; then
    pipx install "changex[preview]" 2>/dev/null || pipx install changex || pipx upgrade changex || true
  elif command -v pip3 >/dev/null 2>&1; then
    pip3 install --user -U "changex[preview]" 2>/dev/null || pip3 install --user -U changex
  else
    warn "No uv / pipx / pip found. Install Python 3 (https://www.python.org/downloads/) or uv"
    warn "(https://docs.astral.sh/uv/), then re-run this script."
    return 1
  fi
  ok "ChangeX installed (try: changex view <file>)."
}

OS="$(uname -s)"
case "$OS" in
  Darwin)
    if ! command -v brew >/dev/null 2>&1; then
      warn "Homebrew is required to install the Qedit app. Install it from https://brew.sh and re-run."
      warn "Continuing with ChangeX only for now…"
    else
      say "Installing Qedit (find + edit any file, with Quick Look previews)…"
      brew tap ariomoniri/qedit https://github.com/ArioMoniri/Qedit >/dev/null 2>&1 || true
      brew install --cask qedit 2>/dev/null || brew upgrade --cask qedit || true
      ok "Qedit installed."
    fi

    install_changex || true

    if command -v changex >/dev/null 2>&1; then
      say "Enabling the ChangeX Quick Look preview…"
      changex quicklook enable 2>/dev/null || warn "Run 'changex quicklook enable' yourself if the preview doesn't show."
    fi

    if [ -d "/Applications/Qedit.app" ]; then
      say "Registering Qedit's Quick Look extension (opening it once)…"
      open -ga Qedit 2>/dev/null || true
    fi

    cat <<'NEXT'

──────────────────────────────────────────────────────────────────────────────
✓ macOS suite installed.
  • Qedit   → opens once to register; in Setup tap "Enable Qedit Preview".
              Press Space on a .md / .swift / .log, or open any file to edit it.
  • ChangeX → 'changex view <file>' for the tracked-changes review;
              Space on a .changex (and supported types) once its Quick Look is on.
  • Not seeing a preview? System Settings → General →
    Login Items & Extensions → Quick Look → enable Qedit and ChangeX,
    then run 'qlmanage -r' (or log out/in).
──────────────────────────────────────────────────────────────────────────────
NEXT
    ;;

  Linux)
    warn "Qedit is a macOS app — its edit-in-Quick-Look features use macOS-only APIs, so there is"
    warn "no Linux build. Installing the cross-platform ChangeX instead."
    install_changex || exit 1
    cat <<'NEXT'

──────────────────────────────────────────────────────────────────────────────
✓ ChangeX installed (Linux).
  • Review changes:   changex view <file>     (zero-install local HTML page)
  • Render to HTML:   changex preview <file>
──────────────────────────────────────────────────────────────────────────────
NEXT
    ;;

  *)
    warn "Unsupported OS '$OS'. On Windows run scripts/install.ps1 (see the README)."
    exit 1
    ;;
esac
