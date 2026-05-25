#!/usr/bin/env bash
# =============================================================================
# capture-wsl.sh — WSL-side baseline capture.
#
# Runs every query in queries/wsl/*.sql via osqueryi, normalizes the JSON with
# jq -S (sorted keys for clean diffs), and collects supplementary data that
# osquery doesn't surface well (apt-mark, dev-tool versions, VS Code
# extensions, etc.). Output lands in baselines/wsl/<timestamp>/.
#
# Idempotent per timestamp: pass TS=... in env to share a timestamp with the
# Windows side (capture-all.sh does this).
#
# Never auto-commits, never pushes. Errors are logged into _summary.md and the
# script continues so a single failure doesn't lose the rest of the capture.
# =============================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TS="${TS:-$(date +%Y-%m-%d_%H%M)}"
OUT_DIR="$REPO_ROOT/baselines/wsl/$TS"
QUERY_DIR="$REPO_ROOT/queries/wsl"
SUMMARY="$OUT_DIR/_summary.md"

mkdir -p "$OUT_DIR"

OSQUERY_VER="$(osqueryi --version 2>/dev/null | awk '{print $NF}' || echo unknown)"

# Errors are accumulated in a temp file so we can write the final _summary.md
# with a clean "Errors" section after all captures finish.
ERR_TMP="$(mktemp)"
trap 'rm -f "$ERR_TMP"' EXIT

note_error() {
    # $1 = artifact name, $2 = short reason
    echo "- \`$1\` — $2" >> "$ERR_TMP"
}

# -----------------------------------------------------------------------------
# osquery queries
# -----------------------------------------------------------------------------
echo "[wsl] osquery (queries/wsl/*.sql) -> $OUT_DIR"

shopt -s nullglob
for sql in "$QUERY_DIR"/*.sql; do
    name="$(basename "$sql" .sql)"
    out="$OUT_DIR/${name}.json"
    raw="$(mktemp)"
    err_log="$(mktemp)"

    if osqueryi --json < "$sql" > "$raw" 2> "$err_log"; then
        # jq -S sorts object keys; SQL ORDER BY already handles array order.
        # Wrap non-arrays into arrays so output shape is uniform.
        if jq -S 'if type == "array" then . else [.] end' "$raw" > "$out" 2>>"$err_log"; then
            :
        else
            echo "[]" > "$out"
            note_error "${name}.json" "jq normalization failed: $(tr '\n' ' ' < "$err_log" | head -c 200)"
        fi
    else
        echo "[]" > "$out"
        note_error "${name}.json" "osqueryi failed: $(tr '\n' ' ' < "$err_log" | head -c 200)"
    fi

    rm -f "$raw" "$err_log"
done
shopt -u nullglob

# -----------------------------------------------------------------------------
# Supplementals (osquery doesn't cover these well)
# -----------------------------------------------------------------------------
echo "[wsl] supplementals"

# apt-mark showmanual — packages the user actually asked for (much cleaner
# signal than the full dpkg list for "what's intentionally installed").
if apt-mark showmanual 2>/dev/null | sort > "$OUT_DIR/apt-manual.txt"; then
    :
else
    note_error "apt-manual.txt" "apt-mark showmanual failed"
fi

# snap
if command -v snap >/dev/null 2>&1; then
    snap list > "$OUT_DIR/snap-list.txt" 2>/dev/null \
        || note_error "snap-list.txt" "snap list failed"
fi

# flatpak
if command -v flatpak >/dev/null 2>&1; then
    flatpak list > "$OUT_DIR/flatpak-list.txt" 2>/dev/null \
        || note_error "flatpak-list.txt" "flatpak list failed"
fi

# dev-tools.json — versions of common dev tools, JSON object keyed by tool name.
# Done in Python because building structured JSON in bash is misery.
if ! python3 - "$OUT_DIR/dev-tools.json" <<'PYEOF' 2>/dev/null; then
import json, shutil, subprocess, sys

TOOLS = {
    "node":    ["node", "--version"],
    "npm":     ["npm", "--version"],
    "python3": ["python3", "--version"],
    "pip3":    ["pip3", "--version"],
    "pipx":    ["pipx", "--version"],
    "cargo":   ["cargo", "--version"],
    "rustc":   ["rustc", "--version"],
    "go":      ["go", "version"],
    "deno":    ["deno", "--version"],
    "bun":     ["bun", "--version"],
    "docker":  ["docker", "--version"],
    "git":     ["git", "--version"],
    "gh":      ["gh", "--version"],
    "code":    ["code", "--version"],
    "nvim":    ["nvim", "--version"],
}

out = {}
for name, cmd in TOOLS.items():
    if not shutil.which(cmd[0]):
        out[name] = None
        continue
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=10)
        v = (r.stdout or r.stderr).strip()
        out[name] = v.splitlines()[0] if v else "(no output)"
    except Exception as e:
        out[name] = f"(error: {type(e).__name__})"

with open(sys.argv[1], "w") as f:
    json.dump(out, f, indent=2, sort_keys=True)
    f.write("\n")
PYEOF
    note_error "dev-tools.json" "python helper failed"
fi

# npm globals
if command -v npm >/dev/null 2>&1; then
    npm ls -g --depth=0 > "$OUT_DIR/npm-globals.txt" 2>/dev/null \
        || note_error "npm-globals.txt" "npm ls failed"
fi

# pipx
if command -v pipx >/dev/null 2>&1; then
    pipx list --short > "$OUT_DIR/pipx-list.txt" 2>/dev/null \
        || note_error "pipx-list.txt" "pipx list failed"
fi

# cargo
if command -v cargo >/dev/null 2>&1; then
    cargo install --list > "$OUT_DIR/cargo-installed.txt" 2>/dev/null \
        || note_error "cargo-installed.txt" "cargo install --list failed"
fi

# go
if command -v go >/dev/null 2>&1; then
    GOBIN="$(go env GOPATH 2>/dev/null)/bin"
    if [ -d "$GOBIN" ]; then
        ls "$GOBIN" 2>/dev/null | sort > "$OUT_DIR/go-installed.txt" || true
    fi
fi

# VS Code extensions. The `code` CLI in WSL usually proxies to the Windows VS
# Code install, so we mirror the same list into configs/windows/vscode/ to
# track it as a Windows-side artifact too.
if command -v code >/dev/null 2>&1; then
    if code --list-extensions --show-versions > "$OUT_DIR/vscode-extensions.txt" 2>/dev/null; then
        mkdir -p "$REPO_ROOT/configs/windows/vscode"
        cp "$OUT_DIR/vscode-extensions.txt" "$REPO_ROOT/configs/windows/vscode/extensions.txt"
    else
        note_error "vscode-extensions.txt" "code --list-extensions failed"
    fi
fi

# wsl.conf
if [ -f /etc/wsl.conf ]; then
    cp /etc/wsl.conf "$OUT_DIR/wsl-conf.txt"
fi

# Shell versions
{
    echo "Current \$SHELL: ${SHELL:-unknown}"
    echo "bash: $(bash --version 2>/dev/null | head -1 || echo n/a)"
    echo "zsh:  $(zsh --version 2>/dev/null | head -1 || echo n/a)"
} > "$OUT_DIR/shell.txt"

# -----------------------------------------------------------------------------
# Final _summary.md
# -----------------------------------------------------------------------------
{
    echo "# WSL baseline capture — ${TS}"
    echo ""
    echo "- Hostname: \`$(hostname)\`"
    echo "- Kernel: \`$(uname -srv)\`"
    echo "- Distro: \`$(lsb_release -ds 2>/dev/null || echo unknown)\`"
    echo "- osquery: \`${OSQUERY_VER}\`"
    echo "- Capture finished: \`$(date -Iseconds)\`"
    echo ""
    echo "## Errors"
    echo ""
    if [ -s "$ERR_TMP" ]; then
        cat "$ERR_TMP"
    else
        echo "(none)"
    fi
    echo ""
    echo "## Files"
    echo ""
    (cd "$OUT_DIR" && du -h --max-depth=1 -- * 2>/dev/null | sort -k2)
} > "$SUMMARY"

err_count=$(wc -l < "$ERR_TMP" | tr -d ' ')
echo "[wsl] done → $OUT_DIR (errors: ${err_count})"
