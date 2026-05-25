# How to refresh the baseline

This repo is meant to be re-captured periodically so that the diff functions
as a changelog of what changed on the machine — packages installed, drivers
updated, services added, configs edited, registry tweaks, hardware swapped.

## Refresh

From WSL, in the repo root:

```bash
./scripts/capture-all.sh
```

That runs, in order:

1. **`capture-wsl.sh`** — WSL osquery passes + apt/snap/dev-tool/extension supplementals.
2. **`capture-windows.ps1`** via `powershell.exe` — Windows osquery passes + winget/Defender/GPU/USB/etc. supplementals.
3. **jq normalization** across the Windows JSON (PowerShell's `ConvertTo-Json` doesn't sort keys; jq `-S` does).
4. **`copy-configs.sh`** — snapshots live dotfiles and app settings into `configs/`, with a per-line secret scan.
5. **Refresh of `baselines/{windows,wsl}/latest`** symlinks (gitignored, local convenience only).

Both sides share a single timestamp, exported as `TS`. The script does **not**
commit and does **not** push.

## Review

```bash
# What changed since the last capture
git status

# Compare a specific group against working tree HEAD
git diff baselines/wsl/$(readlink baselines/wsl/latest)/04-deb-packages.json
git diff baselines/windows/$(readlink baselines/windows/latest)/05-programs.json

# Or compare two specific timestamps directly (no symlinks involved)
PREV=2026-05-01_1430
CURR=$(readlink baselines/windows/latest)
diff -ru baselines/windows/$PREV baselines/windows/$CURR
```

The first capture will look like a massive diff — every file is new. Future
captures are scoped to actual changes.

## Sanity-check before committing

- No files over ~5 MB without a clear reason. `du -sh baselines/*/<ts>` is a
  fast triage. `drivers.json` and `deb-packages.json` are the usual offenders.
- Nothing matching `*secret*`, `*credential*`, `*token*`, `*.pem`, `*.key` is
  staged. `.gitignore` should have caught them, but eyeball `git status` anyway.
- `_summary.md` in each capture dir has a small "Errors" section. A long error
  list is worth investigating before committing the partial snapshot.

## Commit convention

| Prefix | Use for |
| ------ | ------- |
| `baseline: YYYY-MM-DD` | A new capture snapshot (the timestamped dirs + any auto-updated configs). One commit per capture is the norm. |
| `hardware: <change>` | Edits to `hardware/physical-setup.md` or `stuff.txt` (e.g., "UPS added", "swapped to ZenWiFi mesh"). |
| `feat: <change>` | New query packs, new supplementals, new scripts. |
| `fix: <change>` | Bug fixes to scripts. |
| `chore: <change>` | Repo plumbing (`.gitignore` / `.gitattributes` / README / docs). |

If a single capture pulls in multiple kinds of change (e.g., a new query +
the resulting baseline), split into logical commits before the final
`baseline:` commit.

## About `latest/`

`baselines/{windows,wsl}/latest` is a local-only symlink to the most recent
capture dir, refreshed by `capture-all.sh`. It is **gitignored** — diff and
compare via the timestamped dirs directly. The symlink is just a convenience
shortcut for shell commands (`cd baselines/wsl/latest`, etc.). Windows can't
always resolve WSL-created symlinks; if you need a pointer that's Windows-
visible, copy the dir or use `readlink` on the WSL side.

## What to do if a capture fails partway

`_summary.md` in each timestamped dir lists per-artifact errors. To re-run:

```bash
# Re-run, overwriting the existing partial dir for this minute
./scripts/capture-all.sh

# Or wipe and start clean for a specific timestamp
rm -rf baselines/wsl/2026-05-25_1230 baselines/windows/2026-05-25_1230
./scripts/capture-all.sh
```

Individual phases can be re-run in isolation:

```bash
./scripts/capture-wsl.sh                            # WSL only
powershell.exe -NoProfile -ExecutionPolicy Bypass \
    -File "$(wslpath -w scripts/capture-windows.ps1)" -Ts 2026-05-25_1230
./scripts/copy-configs.sh                           # configs only
```
