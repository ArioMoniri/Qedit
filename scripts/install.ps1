# Qedit + ChangeX — Windows suite installer.
#
# Honest note: Qedit itself is a macOS app — its "edit inside Quick Look" features use macOS-only
# frameworks (QuickLookUI / AppKit), so there is NO Windows build of Qedit. The cross-platform part
# of the suite is ChangeX, which this script installs along with its Windows preview handler. For a
# macOS-Quick-Look-style "press Space to preview" experience on Windows, install the free QuickLook
# app (link printed at the end).
#
# Run it with:
#   irm https://raw.githubusercontent.com/ArioMoniri/Qedit/main/scripts/install.ps1 | iex
#
# It only uses uv / pipx / pip (for ChangeX) and prints download links — nothing else runs.

$ErrorActionPreference = 'Stop'
function Say($m)  { Write-Host "▸ $m" -ForegroundColor Cyan }
function Ok($m)   { Write-Host "✓ $m" -ForegroundColor Green }
function Warn($m) { Write-Host "! $m" -ForegroundColor Yellow }

Say "Installing ChangeX (tracked-changes + preview engine)…"
if (Get-Command uv -ErrorAction SilentlyContinue) {
    try { uv tool install --upgrade "changex[preview]" } catch { uv tool install --upgrade changex }
} elseif (Get-Command pipx -ErrorAction SilentlyContinue) {
    try { pipx install "changex[preview]" } catch { pipx install changex }
} elseif (Get-Command pip -ErrorAction SilentlyContinue) {
    try { pip install -U "changex[preview]" } catch { pip install -U changex }
} else {
    Warn "No uv / pipx / pip found. Install Python 3 from https://www.python.org/downloads/"
    Warn "(tick 'Add python.exe to PATH'), then re-run this script."
    exit 1
}
Ok "ChangeX installed (try:  changex view <file> )."

Write-Host ""
Warn "Qedit is macOS-only (its editor uses macOS Quick Look / AppKit APIs) — no Windows build."
Write-Host ""

Say "ChangeX Explorer preview pane (the Windows equivalent of its macOS Quick Look):"
Write-Host "  1. Download 'ChangeX-Windows-Preview.zip' from:"
Write-Host "       https://github.com/ArioMoniri/changex/releases/latest" -ForegroundColor White
Write-Host "  2. Unzip it and run its install.ps1 (registers the handler)."
Write-Host "  3. Select a file in Explorer and press Alt+P to show the preview pane."
Write-Host ""

Say "Optional — a ChangeX Viewer desktop app (double-click window over the same review UI):"
Write-Host "       https://github.com/ArioMoniri/changex/releases/latest  →  ChangeX-Viewer-windows.msi" -ForegroundColor White
Write-Host ""

Say "Optional — Space-to-preview like macOS Quick Look? Install the free 'QuickLook' app for Windows:"
Write-Host "       winget install QL-Win.QuickLook" -ForegroundColor White
Write-Host "   or  https://github.com/QL-Win/QuickLook/releases/latest" -ForegroundColor White
Write-Host ""
Ok "Done. Review changes anywhere with:  changex view <file>"
