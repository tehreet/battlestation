# Claude Code Prompt: Build the `system-baseline` Repo (osquery-driven)

You are running inside WSL (Ubuntu 24.04) on a Windows 11 host (hostname `BATTLESTATION`, user `joshf`). The current working directory is a blank git repo root. There is one seed file already in the root: **`stuff.txt`** — free-form notes covering the hardware and office setup that no software can see (audio chain, desk, chair, KVM, peripheral purchase info).

Your job is to turn this into a **living, queryable, re-runnable snapshot** of everything about this environment — Windows side, WSL side, configs, dotfiles, and the physical hardware. The thesis: anything observable at the software layer should be captured by tooling, not described in prose. **osquery** is the backbone. Everything else is supplementary.

Future commits should produce a meaningful diff of "what changed" — packages installed, drivers updated, services added, config edits, registry tweaks — so the repo functions as both a backup and a changelog.

---

## Phase 0 — Read the seed

Read `stuff.txt` in full before anything else. Summarize for me what you found in it. If it's missing or empty, stop and ask.

---

## Phase 1 — Clarifying questions (ASK BEFORE BUILDING)

osquery + the supplementary scripts will pick up most things — including monitors (via EDID), USB devices, audio interfaces, keyboards/mice if they expose model strings, GPU, RAM modules, etc. So only ask about things that genuinely have **no software footprint**.

Confirm or fill in:

**PC internals with no software signal:**
- Case (model)
- PSU (model + wattage)
- CPU cooler (model — air or AIO?)
- Case fans (count + model)
- Any storage devices beyond what osquery enumerates? (extra HDDs not currently mounted, external drives normally connected)

**Peripherals where the model often isn't in USB descriptors:**
- Specific keyboard model (Keychron — which one?)
- Specific mouse model
- Headphones / headset model
- Mic boom arm or stand
- Any control surfaces (Stream Deck, MIDI controllers, etc.)

**Office / room / network gear:**
- Router, switch, access point — make/model
- UPS — make/model + which devices are on it
- Lighting (smart bulbs, key lights, bias lighting)
- Anything else worth tracking

**Scope decisions:**
- Steam/Epic/Battle.net **games** in the installed-software output: filter out, keep inline, or split to their own file? (Default: split.)
- Browser extensions — Chrome and Edge: capture both? (Default: yes, osquery has tables for this.)
- VS Code extensions: definitely yes.
- WSL: any distros other than the running `Ubuntu`? (`docker-desktop` is Docker's internal, ignore it.)
- Network capture: include `arp_cache` and discovered LAN hosts, or treat that as too noisy/PII-ish? (Default: skip ARP, capture only this host's interfaces and routes.)

Wait for my answers, then proceed.

---

## Phase 2 — Repo scaffold + .gitignore (DO .gitignore FIRST)

### `.gitignore` (be paranoid — write this before anything else gets captured)

Block at minimum:

- SSH/GPG keys: `id_*`, `*.pem`, `*.key`, `*.ppk`, `*.gpg`, `*.asc`, `secring.*`, `**/.gnupg/`, `**/.ssh/id_*`, `**/.ssh/known_hosts`
- Cloud creds: `.aws/credentials`, `.aws/config`, `**/kube/config`, `**/.kube/`, `**/gcloud/`, `**/.azure/`
- Env / secret files: `.env`, `.env.*`, `*.env`, `*secrets*`, `*credentials*`
- Password manager exports: `*.1pux`, `*.csv` anywhere named `password*` or `vault*`, anything under `**/vault*/`
- Browser state: `**/Cookies*`, `**/Login Data*`, `**/Web Data*`, `**/User Data/`
- Tokens / auth: `*token*`, `.netrc`, `_netrc`, `.npmrc`, `.pypirc`, `**/.config/gh/hosts.yml`, `**/.config/claude*/auth*`, `**/.claude/credentials*`, `**/anthropic*/auth*`
- Shell history: `.bash_history`, `.zsh_history`, `.python_history`, `.psql_history`, `.lesshst`, `.viminfo`, `.node_repl_history`
- Caches and build: `node_modules/`, `__pycache__/`, `.venv/`, `venv/`, `*.sqlite`, `*.db`
- OS junk: `.DS_Store`, `Thumbs.db`, `desktop.ini`

Also write `.gitattributes`: force LF on `*.sh`, `*.sql`, `*.json`, `*.md`; force CRLF on `*.ps1`, `*.psm1`, `*.psd1`.

### Then scaffold:

```
.
├── README.md
├── .gitignore
├── .gitattributes
├── stuff.txt                       # leave in place, source for hardware doc
├── baselines/
│   ├── windows/
│   │   ├── latest/                 # symlink or copy of most recent capture
│   │   └── YYYY-MM-DD_HHMM/        # one dir per capture run
│   └── wsl/
│       ├── latest/
│       └── YYYY-MM-DD_HHMM/
├── queries/
│   ├── windows/                    # .sql files, one per logical group
│   └── wsl/
├── scripts/
│   ├── install-osquery-windows.ps1
│   ├── install-osquery-wsl.sh
│   ├── capture-all.sh              # orchestrator, run from WSL
│   ├── capture-windows.ps1         # osquery + supplemental, invoked via powershell.exe
│   ├── capture-wsl.sh              # osquery + supplemental, native bash
│   ├── copy-configs.sh             # snapshots live config files into configs/
│   └── lib/                        # shared helpers
├── configs/
│   ├── windows/
│   │   ├── windows-terminal/
│   │   ├── powershell/
│   │   ├── vscode/
│   │   ├── git/
│   │   ├── winget/                 # winget export JSON
│   │   └── wsl/                    # .wslconfig from %UserProfile%
│   └── wsl/
│       ├── shell/                  # .bashrc, .zshrc, .profile, .inputrc
│       ├── git/
│       ├── ssh/                    # config ONLY
│       ├── vim/
│       └── tools/                  # tmux, starship, atuin, etc.
├── hardware/
│   └── physical-setup.md           # curated from stuff.txt + Phase 1 answers
└── docs/
    └── how-to-update.md
```

Before committing anything, **grep `stuff.txt` for obvious secrets** (`apikey`, `api_key`, `secret`, `password`, `token`, `BEGIN PRIVATE KEY`, AWS prefixes `AKIA`/`ASIA`) and flag anything found.

---

## Phase 3 — Install osquery

### Windows

Check if osquery is already installed: `Get-Command osqueryi.exe` or look in `C:\Program Files\osquery\`. If not, attempt `winget install --id=osquery.osquery -e --accept-source-agreements --accept-package-agreements`. If that fails or needs elevation, stop and give me the manual install command — don't try to fight UAC.

Confirm with `osqueryi --version`.

### WSL

Use the official Linux package. Roughly:

```bash
curl -L https://pkg.osquery.io/deb/pubkey.gpg | sudo gpg --dearmor -o /etc/apt/keyrings/osquery.gpg
echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/osquery.gpg] https://pkg.osquery.io/deb deb main" | sudo tee /etc/apt/sources.list.d/osquery.list
sudo apt update && sudo apt install -y osquery
```

Use the keyrings approach (not `apt-key`, which is deprecated on Ubuntu 24.04). Confirm with `osqueryi --version`.

---

## Phase 4 — Query packs (`queries/`)

Write one `.sql` file per logical group. Each file should be runnable standalone with `osqueryi --json < file.sql`. Keep queries small enough that the JSON output for each is reviewable in a diff.

### `queries/windows/` (minimum set — add more if obvious gaps exist):

- `01-system.sql` — `system_info`, `os_version`, `kernel_info`, `cpu_info`, `memory_devices`, `wmi_bios_info`, `platform_info`, `uptime`, `time`
- `02-storage.sql` — `logical_drives`, `disk_info`, `physical_disk_performance` (just current snapshot fields), `bitlocker_info`
- `03-display-monitors.sql` — `wmi_monitor_id` (or equivalent), `video_info`
- `04-network-interfaces.sql` — `interface_addresses`, `interface_details`, `routes`, `listening_ports`
- `05-programs.sql` — `programs` (full installed list). Filter games into a separate output per Phase 1.
- `06-patches.sql` — `patches` (Windows updates / KBs)
- `07-services.sql` — `services` where `start_type` is not `DISABLED`
- `08-processes.sql` — `processes` joined with `process_open_sockets` for the listening picture, plus top-RAM snapshot
- `09-startup.sql` — `startup_items`, `autoexec`
- `10-scheduled-tasks.sql` — `scheduled_tasks` where path is not under `\Microsoft\` (filter out OS noise)
- `11-drivers.sql` — `drivers` (this is big — keep it but in its own file)
- `12-users-groups.sql` — `users`, `groups`, `logged_in_users` (sanitize: skip last_logon hashes)
- `13-security.sql` — `windows_security_products`, `windows_security_center`, `bitlocker_info`, Defender status
- `14-certificates.sql` — `certificates` from `LocalMachine\Root` and `LocalMachine\My` (just summary fields: subject, issuer, not_valid_after, sha1)
- `15-browser-extensions.sql` — `chrome_extensions`, `ie_extensions`
- `16-registry-autorun.sql` — `registry` queries against the standard autorun keys (Run, RunOnce, Image File Execution Options)
- `17-shared-and-pipes.sql` — `shared_resources`, `pipes` (named pipes — interesting forensic surface)
- `18-environment.sql` — `environment` for SYSTEM + current user, **with redaction** of any value matching secret patterns (Claude Code, write a filter for this — don't dump raw)

### `queries/wsl/`:

- `01-system.sql` — `system_info`, `os_version`, `kernel_info`, `cpu_info`, `memory_info`, `uptime`
- `02-storage.sql` — `block_devices`, `mounts`
- `03-network.sql` — `interface_addresses`, `interface_details`, `routes`, `listening_ports`
- `04-packages-deb.sql` — `deb_packages` (full list)
- `05-packages-lang.sql` — `npm_packages`, `python_packages` (these are language-specific, may be empty)
- `06-processes.sql` — `processes`, `process_open_sockets`
- `07-users.sql` — `users`, `groups`, `logged_in_users`
- `08-cron.sql` — `crontab`
- `09-ssh.sql` — `ssh_configs` (config files, not keys), `authorized_keys` SUMMARY ONLY (count + comment fields, never raw key material)
- `10-startup.sql` — `startup_items`
- `11-services-systemd.sql` — `systemd_units` if available (systemd in WSL works since recent versions; gracefully skip if unavailable)

If osquery doesn't expose a table needed for one of these (some are platform-conditional), have the query log a clear `-- unavailable on this platform` comment and produce an empty JSON array.

---

## Phase 5 — Capture scripts

### Output format rules (apply to every capture):

- All osquery output: `osqueryi --json < query.sql | jq -S 'sort_by(.<stable_key>) // .' > output.json`
  - `-S` sorts JSON keys → cleaner diffs
  - Sort the array on whatever field makes records uniquely ordered (e.g. `name` for programs, `pid` is bad because PIDs change, prefer `path` or `name`)
  - If no stable key, sort lexicographically by the whole record
- Files written as UTF-8, no BOM, LF line endings
- Timestamp format: `YYYY-MM-DD_HHMM` local time, used both for the capture dir name and any inline metadata

### `scripts/capture-windows.ps1`

Invoked via `powershell.exe -ExecutionPolicy Bypass -File <wsl-path-translated>`. Run all `queries/windows/*.sql` through `osqueryi` and write JSON to `baselines/windows/<timestamp>/`.

Also produce supplementals (osquery doesn't cover these well):

- `winget-export.json` — `winget export -o <path> --include-versions --accept-source-agreements`
- `winget-sources.txt` — `winget source list`
- `windows-capabilities.json` — `Get-WindowsCapability -Online | Where State -eq Installed | Select Name, State | ConvertTo-Json`
- `windows-features.json` — `Get-WindowsOptionalFeature -Online | Where State -eq Enabled | Select FeatureName | ConvertTo-Json`
- `defender-status.json` — `Get-MpComputerStatus | ConvertTo-Json` (sanitize: drop hash-y fields)
- `powershell-modules.json` — `Get-Module -ListAvailable | Select Name, Version, Path | ConvertTo-Json`
- `office-info.txt` — registry probe under `HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Configuration` for channel + version (if installed)
- `gpu-displays.json` — supplement osquery's display info with `Get-CimInstance Win32_VideoController` (driver date/version) and `Get-CimInstance -Namespace root/wmi WmiMonitorID` (decoded model strings)
- `usb-devices.json` — `Get-PnpDevice -PresentOnly | Where Class -in @('USB','HIDClass','AudioEndpoint','Camera','Bluetooth') | Select FriendlyName, Class, InstanceId, Manufacturer | ConvertTo-Json`
- `power-plan.txt` — `powercfg /getactivescheme`
- `bcdedit.txt` — `bcdedit /enum` (boot config — useful for tracking when boot params change)

Write a `_summary.md` for the capture dir with: hostname, capture time, osquery version, total file count, file sizes, and any errors encountered (don't silently swallow failures — write an `ERROR:` line into `_summary.md` and continue).

### `scripts/capture-wsl.sh`

`set -euo pipefail`. Run all `queries/wsl/*.sql` through osqueryi, output to `baselines/wsl/<timestamp>/`.

Supplementals:

- `apt-manual.txt` — `apt-mark showmanual | sort` (cleaner than full deb_packages for tracking *intentional* installs)
- `snap-list.txt` — if snap is installed
- `flatpak-list.txt` — if flatpak is installed
- `dev-tools.json` — JSON object capturing versions of: `node`, `npm`, `python3`, `pip3`, `pipx`, `cargo`, `rustc`, `go`, `deno`, `bun`, `docker`, `git`, `gh`, `code`, `nvim`. Skip any that aren't installed.
- `npm-globals.txt` — `npm ls -g --depth=0` (text is fine, parsing is annoying)
- `pipx-list.txt` — `pipx list --short` if pipx
- `cargo-installed.txt` — `cargo install --list`
- `go-installed.txt` — `ls "$(go env GOPATH 2>/dev/null)/bin" 2>/dev/null`
- `vscode-extensions.txt` — `code --list-extensions --show-versions` (this is the user's actual VS Code install — write to **both** `baselines/wsl/<ts>/` and `configs/windows/vscode/extensions.txt` since it's the same install used from WSL)
- `wsl-conf.txt` — `cat /etc/wsl.conf` if present
- `shell.txt` — current `$SHELL`, plus version of bash and zsh

`_summary.md` same format as Windows side.

### `scripts/capture-all.sh`

Orchestrator. Order:

1. `scripts/capture-wsl.sh`
2. `powershell.exe` → `scripts/capture-windows.ps1`
3. `scripts/copy-configs.sh`
4. Update `baselines/{windows,wsl}/latest` to point at the new dirs (symlink on WSL side, plain copy on Windows side if symlinks misbehave)
5. Print `git status` and the total size of new files
6. **Do not auto-commit and do not push.** I review the diff myself.

---

## Phase 6 — Config file snapshots (`scripts/copy-configs.sh`)

Copy live configs into `configs/` so the repo holds actual checked-in copies. Determine the Windows user from `/mnt/c/Users/` (ignore `Public`, `Default*`, `All Users`). For the seed system that user is `joshf` — confirm.

### Windows (via `/mnt/c/`):
- Windows Terminal: `/mnt/c/Users/<user>/AppData/Local/Packages/Microsoft.WindowsTerminal_*/LocalState/settings.json`
- PowerShell: `Documents/PowerShell/Microsoft.PowerShell_profile.ps1` (pwsh 7) and `Documents/WindowsPowerShell/Microsoft.PowerShell_profile.ps1`
- VS Code: `AppData/Roaming/Code/User/{settings.json,keybindings.json,snippets/}`
- Git: `/mnt/c/Users/<user>/.gitconfig`
- `.wslconfig` from `/mnt/c/Users/<user>/.wslconfig` if present

### WSL:
- `~/.bashrc`, `~/.bash_profile`, `~/.profile`, `~/.zshrc`, `~/.zprofile`, `~/.zshenv`
- `~/.inputrc`, `~/.editrc`
- `~/.gitconfig`, `~/.gitignore_global`
- `~/.vimrc`, `~/.config/nvim/` (full tree)
- `~/.tmux.conf`, `~/.config/tmux/`
- `~/.config/starship.toml`, `~/.config/atuin/config.toml`, `~/.config/zellij/`, `~/.config/wezterm/`
- `~/.ssh/config` **ONLY** — never `id_*`, never `known_hosts`

**Pre-copy sanitization**: scan each file for token-like patterns before copying. If a match is found, copy the file with the offending line replaced by `# REDACTED: <pattern matched> — original line removed by capture script on <timestamp>` and warn in the script output.

---

## Phase 7 — `hardware/physical-setup.md`

Curate from `stuff.txt` + my Phase 1 answers. Structure:

- **PC internals** — case, PSU, cooler, fans, anything else I added (the *software-observable* parts like CPU/mobo/RAM/GPU/storage will live in the baselines, but a short pointer here is fine)
- **Monitors and mounts** — Ergotron LX arms, monitors (cross-reference what osquery captures)
- **Audio chain** — mic → Focusrite → hum eliminator → Kanto speakers/sub, drawn as an explicit signal-flow list. Include cable types/connectors if I mentioned them.
- **KVM and multi-machine setup** — TESmart KVM, hosts attached (Windows PC + work MacBook M5 Max), Synergy app role
- **Peripherals** — keyboard, mouse, headphones, webcam, etc. (from my Phase 1 answers, even where osquery might also see them)
- **Desk and seating** — UPLIFT desk + SKUs, Embody chair config
- **Network gear** — router/switch/AP/UPS from Phase 1

Keep purchase links from `stuff.txt` but mark them as **reference** (not "current price"). Don't editorialize.

---

## Phase 8 — README + how-to-update

`README.md` (short):
- One paragraph: what this repo is.
- Quick-start: prereqs, then `./scripts/capture-all.sh`.
- Pointer to `docs/how-to-update.md`.

`docs/how-to-update.md`:
- Exact commands to refresh the baseline.
- How to review a diff before committing (e.g., `git diff baselines/windows/latest/`).
- Suggested commit message convention: `baseline: YYYY-MM-DD` for captures, normal messages for manual edits, `hardware: <change>` for physical changes.
- Note on `latest/` symlinks/copies and how they're updated.

---

## Phase 9 — First run + initial commits

After scaffolding:

1. Run `scripts/capture-all.sh`. If anything fails, show me the error before continuing.
2. Show `git status` and file-size summary.
3. Sanity-check the staging set: no files look like secrets, no files over ~5MB without good reason.
4. Stage and commit in logical chunks, separate commits:
   - `chore: scaffold repo structure and .gitignore`
   - `feat: add osquery install scripts`
   - `feat: add query packs`
   - `feat: add capture scripts`
   - `baseline: <timestamp> initial capture`
   - `feat: snapshot live configs`
   - `docs: hardware setup and README`
5. **Do not push.** I'll set the remote.

---

## Working style

- Pause and ask when something is ambiguous. Don't guess my hardware or my preferences.
- Show your work in chunks; don't disappear for 20 tool calls and return a wall of text.
- If a capture command fails on this system, write a clear `ERROR:` line in the output and continue — don't silently drop the section.
- Comment the scripts well. These need to be readable a year from now.
- Prefer JSON for machine-generated output (diffs well), markdown for human-written narrative (README, hardware doc), `.sql` for queries.

Start with Phase 0. Read `stuff.txt`, summarize it for me, then ask the Phase 1 questions. Don't scaffold until I've answered.