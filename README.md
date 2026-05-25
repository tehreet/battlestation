# system-baseline

A queryable, re-runnable snapshot of this machine — Windows side, WSL side,
configs, dotfiles, and physical hardware. [osquery](https://osquery.io) is the
backbone; everything else is supplementary.

The thesis: anything observable at the software layer should be captured by
tooling, not described in prose. Hardware and physical-setup notes that
*can't* be queried live in [`hardware/physical-setup.md`](hardware/physical-setup.md)
(curated by hand). Future commits produce a meaningful diff of "what changed"
— packages installed, drivers updated, services added, config edits, registry
tweaks — so the repo functions as both a backup and a changelog.

## Layout

| Path | What's in it |
| ---- | ------------ |
| `baselines/{windows,wsl}/<timestamp>/` | per-run JSON snapshots |
| `queries/{windows,wsl}/*.sql` | osquery query packs (one query per file) |
| `scripts/` | install + capture + config-snapshot scripts |
| `configs/{windows,wsl}/` | checked-in copies of live dotfiles and app settings |
| `hardware/physical-setup.md` | case, audio chain, monitors, peripherals, desk |
| `stuff.txt` | raw hardware/purchase notes (source material for `hardware/`) |
| `docs/how-to-update.md` | refresh workflow + commit conventions |

## Quick-start

Prereqs: WSL Ubuntu, PowerShell, `jq` (apt installs it as a transitive of osquery).

```bash
# one-time install
./scripts/install-osquery-wsl.sh
./scripts/install-osquery-windows.ps1   # or via PowerShell directly, elevated

# every capture, from WSL
./scripts/capture-all.sh
```

`capture-all.sh` writes everything under `baselines/<ts>/` and `configs/`,
refreshes the local-only `latest` symlinks, and prints a `git status` + size
summary. **It never commits, never pushes** — review the diff yourself, then
commit per the convention in [`docs/how-to-update.md`](docs/how-to-update.md).

## Safety notes

- `.gitignore` is paranoid by default: SSH/GPG keys, cloud creds, env files,
  password-manager exports, browser state, shell history, and common token
  patterns are blocked.
- `copy-configs.sh` runs a secret scan on every config file before copying,
  and replaces any matching line with a `# REDACTED:` marker (originals are
  not modified — only the snapshot in `configs/` is sanitized).
- osquery `authorized_keys` capture pulls only metadata (uid, algorithm,
  comment, file path) — never raw key material.
- Environment-variable captures redact values whose names match
  TOKEN/KEY/SECRET/PASSWORD/AUTH/CREDENTIAL/API patterns.

If you push this repo to a public remote, audit a fresh capture diff first.
