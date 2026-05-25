#!/usr/bin/env bash
# =============================================================================
# copy-configs.sh — snapshot live config files into configs/ for version
# control. Runs after the osquery captures so the repo holds actual checked-in
# copies of the dotfiles + app settings, not just metadata about them.
#
# Pre-copy secret scan: any line matching the SECRET_RE patterns is replaced
# with a REDACTED marker (and the script prints a warning). The original
# file is never modified — we only ever read from source and write to dest.
#
# SSH config is copied; SSH keys and known_hosts are NEVER copied.
# =============================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CFG_WIN="$REPO_ROOT/configs/windows"
CFG_WSL="$REPO_ROOT/configs/wsl"

# Determine the Windows user. Filter out system/default profiles.
WIN_USER=""
if [ -d /mnt/c/Users ]; then
    for d in /mnt/c/Users/*/; do
        u="$(basename "$d")"
        case "$u" in
            Public|Default|Default\ User|All\ Users|defaultuser0|WDAGUtilityAccount) continue ;;
        esac
        # Prefer the user matching $USER if present.
        if [ "$u" = "$USER" ]; then
            WIN_USER="$u"
            break
        fi
        # Otherwise, take the first real user.
        if [ -z "$WIN_USER" ]; then
            WIN_USER="$u"
        fi
    done
fi
if [ -z "$WIN_USER" ]; then
    echo "[configs] WARNING: could not detect Windows user under /mnt/c/Users; skipping Windows config copy."
fi
WIN_HOME="/mnt/c/Users/$WIN_USER"

# -----------------------------------------------------------------------------
# Secret patterns. Lines matching any of these are redacted on copy.
# Goal: catch obvious leaks (API keys, tokens, PEM headers, AWS prefixes,
# GitHub PATs) without going so wide that every comment containing "key"
# disappears.
# -----------------------------------------------------------------------------
SECRET_RE='(api[_-]?key|secret|password|passwd|token)[[:space:]]*[:=][[:space:]]*[^[:space:]"'\'']{6,}|BEGIN [A-Z ]*PRIVATE KEY|AKIA[0-9A-Z]{16}|ASIA[0-9A-Z]{16}|gh[pousr]_[A-Za-z0-9]{30,}|xox[abopr]-[A-Za-z0-9-]{10,}'

REDACT_TS="$(date -Iseconds)"
WARN_COUNT=0

# copy_with_scan SRC DST — copy SRC to DST, redacting lines that match SECRET_RE.
copy_with_scan() {
    local src=$1 dst=$2
    [ -e "$src" ] || return 0
    mkdir -p "$(dirname "$dst")"

    if grep -IqE "$SECRET_RE" "$src" 2>/dev/null; then
        WARN_COUNT=$((WARN_COUNT + 1))
        echo "  ⚠  redacting lines in: $src"
        # Replace matching lines (case-insensitive) with a REDACTED marker.
        sed -E "s|.*(${SECRET_RE}).*|# REDACTED: matched secret pattern — original line removed by copy-configs.sh on ${REDACT_TS}|gI" "$src" > "$dst"
    else
        cp "$src" "$dst"
    fi
}

# copy_tree SRC DST — recursively copy a directory, scanning each text file.
copy_tree() {
    local src=$1 dst=$2
    [ -d "$src" ] || return 0
    while IFS= read -r -d '' f; do
        rel="${f#$src/}"
        copy_with_scan "$f" "$dst/$rel"
    done < <(find "$src" -type f -print0)
}

echo "[configs] copying configs (secret scan: on)"

# -----------------------------------------------------------------------------
# Windows side (read via /mnt/c/)
# -----------------------------------------------------------------------------
if [ -n "$WIN_USER" ] && [ -d "$WIN_HOME" ]; then
    echo "[configs] windows user: $WIN_USER"

    # Windows Terminal — settings.json lives under a versioned package dir.
    for st in "$WIN_HOME"/AppData/Local/Packages/Microsoft.WindowsTerminal_*/LocalState/settings.json; do
        [ -f "$st" ] || continue
        copy_with_scan "$st" "$CFG_WIN/windows-terminal/settings.json"
    done

    # PowerShell 7 profile
    for d in "$WIN_HOME/Documents/PowerShell" "$WIN_HOME/OneDrive/Documents/PowerShell"; do
        copy_with_scan "$d/Microsoft.PowerShell_profile.ps1" "$CFG_WIN/powershell/Microsoft.PowerShell_profile.ps1"
    done

    # Windows PowerShell 5 profile
    for d in "$WIN_HOME/Documents/WindowsPowerShell" "$WIN_HOME/OneDrive/Documents/WindowsPowerShell"; do
        copy_with_scan "$d/Microsoft.PowerShell_profile.ps1" "$CFG_WIN/powershell/Microsoft.PowerShell_profile_v5.ps1"
    done

    # VS Code user settings + keybindings + snippets
    VSCODE_USER="$WIN_HOME/AppData/Roaming/Code/User"
    if [ -d "$VSCODE_USER" ]; then
        copy_with_scan "$VSCODE_USER/settings.json"    "$CFG_WIN/vscode/settings.json"
        copy_with_scan "$VSCODE_USER/keybindings.json" "$CFG_WIN/vscode/keybindings.json"
        if [ -d "$VSCODE_USER/snippets" ]; then
            copy_tree "$VSCODE_USER/snippets" "$CFG_WIN/vscode/snippets"
        fi
    fi

    # Git
    copy_with_scan "$WIN_HOME/.gitconfig" "$CFG_WIN/git/.gitconfig"

    # WSL global config
    copy_with_scan "$WIN_HOME/.wslconfig" "$CFG_WIN/wsl/.wslconfig"
fi

# -----------------------------------------------------------------------------
# WSL side (read $HOME)
# -----------------------------------------------------------------------------
echo "[configs] wsl user: $USER (home: $HOME)"

# Shells
for f in .bashrc .bash_profile .profile .bash_logout .zshrc .zprofile .zshenv .zlogin .zlogout; do
    copy_with_scan "$HOME/$f" "$CFG_WSL/shell/$f"
done
copy_with_scan "$HOME/.inputrc" "$CFG_WSL/shell/.inputrc"
copy_with_scan "$HOME/.editrc"  "$CFG_WSL/shell/.editrc"

# Git
copy_with_scan "$HOME/.gitconfig"        "$CFG_WSL/git/.gitconfig"
copy_with_scan "$HOME/.gitignore_global" "$CFG_WSL/git/.gitignore_global"

# Vim / Neovim
copy_with_scan "$HOME/.vimrc" "$CFG_WSL/vim/.vimrc"
copy_tree "$HOME/.config/nvim" "$CFG_WSL/vim/nvim"

# Tools (tmux, starship, atuin, zellij, wezterm)
copy_with_scan "$HOME/.tmux.conf"                "$CFG_WSL/tools/.tmux.conf"
copy_tree "$HOME/.config/tmux"                   "$CFG_WSL/tools/tmux"
copy_with_scan "$HOME/.config/starship.toml"     "$CFG_WSL/tools/starship.toml"
copy_with_scan "$HOME/.config/atuin/config.toml" "$CFG_WSL/tools/atuin/config.toml"
copy_tree "$HOME/.config/zellij"                 "$CFG_WSL/tools/zellij"
copy_tree "$HOME/.config/wezterm"                "$CFG_WSL/tools/wezterm"

# SSH — config ONLY. Never copy id_* or known_hosts.
copy_with_scan "$HOME/.ssh/config" "$CFG_WSL/ssh/config"

if [ $WARN_COUNT -gt 0 ]; then
    echo "[configs] done — ${WARN_COUNT} file(s) had matches redacted on copy."
else
    echo "[configs] done — no secret patterns matched."
fi
