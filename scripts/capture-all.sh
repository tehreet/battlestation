#!/usr/bin/env bash
# =============================================================================
# capture-all.sh — orchestrator. Runs from WSL.
#
#   1) capture-wsl.sh                       (Linux side, native bash)
#   2) capture-windows.ps1 via powershell.exe  (Windows side)
#   3) jq -S normalizes Windows JSON         (PowerShell can't sort keys cleanly)
#   4) copy-configs.sh                       (live config snapshots, scanned)
#   5) Refreshes baselines/{windows,wsl}/latest symlinks
#   6) Prints `git status` + new-file footprint
#
# Both Windows and WSL captures share the same timestamp (exported as TS) so
# every artifact in this run is grouped together.
#
# Never commits, never pushes. The diff is for you to review.
# =============================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TS="$(date +%Y-%m-%d_%H%M)"
export TS

echo "============================================================"
echo "system-baseline capture — $TS"
echo "============================================================"
echo ""

# -----------------------------------------------------------------------------
# 1) WSL
# -----------------------------------------------------------------------------
echo "==> [1/5] capture-wsl.sh"
"$REPO_ROOT/scripts/capture-wsl.sh"
echo ""

# -----------------------------------------------------------------------------
# 2) Windows (via powershell.exe)
# -----------------------------------------------------------------------------
echo "==> [2/5] capture-windows.ps1"
PS_SCRIPT_WIN="$(wslpath -w "$REPO_ROOT/scripts/capture-windows.ps1")"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$PS_SCRIPT_WIN" -Ts "$TS"
echo ""

# -----------------------------------------------------------------------------
# 3) Normalize Windows JSON with jq -S (sorted keys → cleaner diffs).
#    PowerShell's ConvertTo-Json doesn't sort keys, so we re-emit from WSL.
# -----------------------------------------------------------------------------
echo "==> [3/5] normalize Windows JSON (jq -S)"
WIN_OUT="$REPO_ROOT/baselines/windows/$TS"
if [ -d "$WIN_OUT" ]; then
    norm_ok=0
    norm_fail=0
    for f in "$WIN_OUT"/*.json; do
        [ -f "$f" ] || continue
        if jq -S '.' "$f" > "$f.tmp" 2>/dev/null; then
            mv "$f.tmp" "$f"
            norm_ok=$((norm_ok + 1))
        else
            rm -f "$f.tmp"
            norm_fail=$((norm_fail + 1))
            echo "  ! could not normalize $(basename "$f")"
        fi
    done
    echo "  $norm_ok normalized, $norm_fail failed"
fi
echo ""

# -----------------------------------------------------------------------------
# 4) Config snapshots
# -----------------------------------------------------------------------------
echo "==> [4/5] copy-configs.sh"
"$REPO_ROOT/scripts/copy-configs.sh"
echo ""

# -----------------------------------------------------------------------------
# 5) latest pointers (local-only, gitignored) + status
# -----------------------------------------------------------------------------
echo "==> [5/5] refresh latest pointers"
ln -sfn "$TS" "$REPO_ROOT/baselines/wsl/latest"
ln -sfn "$TS" "$REPO_ROOT/baselines/windows/latest"

echo ""
echo "------------------------------------------------------------"
echo "git status (short)"
echo "------------------------------------------------------------"
(cd "$REPO_ROOT" && git status --short) || true

echo ""
echo "------------------------------------------------------------"
echo "New capture footprint"
echo "------------------------------------------------------------"
du -sh "$REPO_ROOT/baselines/wsl/$TS"     2>/dev/null || true
du -sh "$REPO_ROOT/baselines/windows/$TS" 2>/dev/null || true

echo ""
echo "Capture complete. Review the diff, then commit yourself —"
echo "this script does not auto-commit and does not push."
