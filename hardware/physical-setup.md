# Physical Setup

Snapshot of the physical / non-software-observable hardware in the BATTLESTATION
setup. Software-observable components (CPU, motherboard, RAM, GPU, storage,
displays, USB descriptors) live in the JSON captures under `baselines/`. This
file is only for what software *can't* see.

When a piece of gear has both a software footprint and an off-the-shelf model
name, the model is noted here and a pointer to the baseline JSON is given.

---

## PC internals

| Component | Detail |
| --------- | ------ |
| Case | Generic mini-ITX (no specific model recorded) |
| PSU | Corsair SF1000 (SF Series 2024), 80 PLUS Platinum, fully modular SFX — `CP-9020257-NA` |
| CPU cooler | Corsair H100i, 240 mm AIO liquid cooler — *TODO: confirm exact variant (H100i Elite / H100i RGB Pro XT / etc.)* |
| Case fans | 5× (model not recorded) |
| Extra storage | None beyond what's mounted |

CPU / motherboard / RAM / GPU / storage details — see
`baselines/windows/latest/01-system.json` and `02-storage.json`.

---

## Monitors and mounts

- **Monitor arms** — 2× Ergotron LX Desk Mount Monitor Arm, Matte Black
  (`ER45241224`)

Monitor make/model + EDID details captured in
`baselines/windows/latest/03-display-monitors.json` (driver and `WmiMonitorID`
decode).

---

## Audio chain

Signal flow, source → destination:

1. **Microphone** — Shure SM7B (dynamic, XLR)
2. **Boom arm** — Rode (specific model not recorded)
3. **Audio interface** — Focusrite Scarlett 2i2, 4th Gen (USB)
4. **Hum eliminator** — Morley MHE 2-channel stereo (between interface line-out
   and powered speakers)
5. **Speakers** — Kanto YU6 (powered)
6. **Subwoofer** — Kanto SUB8MW (8" paper cone driver, matte white)
7. **Headphones** — Drop HD-6XX, plugged into the Scarlett 2i2 headphone out

The Scarlett, headphones, and mic typically show up in
`baselines/windows/latest/usb-devices.json` — the speakers/sub do not (analog
chain past the interface is invisible to software).

---

## KVM and multi-machine

- **KVM** — TESmart 4K@144Hz DisplayPort KVM Switch (2 monitors × 4 computers)
  - DP 1.4, 8K@60Hz, USB 3.0, EDID passthrough, gigabit Ethernet, hotkey
    switching, VRR
- **Hosts attached:**
  - This Windows PC (`BATTLESTATION`)
  - Work MacBook Pro — M5 Max, 40 GPU cores
- **Keyboard/mouse sharing** — Synergy app (separate from KVM, runs on top so
  KB/mouse moves between machines without flipping the KVM)

---

## Peripherals

| Class | Item |
| ----- | ---- |
| Keyboard | Keychron Q1 HE Wireless — Hall Effect Gateron double-rail magnetic switches, rapid trigger, QMK, 2.4 GHz + BT 5.2, RGB, hot-swappable |
| Mouse | Logitech MX Master 4 |
| Headphones | Drop HD-6XX (see audio chain) |
| Webcam | Logitech Brio 4K |
| Mic boom arm | Rode (specific model unknown) |
| Control surfaces | None |

---

## Desk and seating

**Desk — UPLIFT V2 L-Shaped Standing Desk** (delivered March 2025)

| Component | SKU | Notes |
| --------- | --- | ----- |
| Main top | `TOP402-LSHAPE-80X30-MAIN-G` | 80" × 30" walnut laminate, GREENGUARD, with grommets |
| Return | `TOP402-LSHAPE-48X27-RTN` | 48" × 27.5" walnut laminate, GREENGUARD, no grommets |
| Frame (Box 1) | `F550B` | L-shaped frame, black |
| Frame (Box 2) | `F551B` | L-shaped frame, black |
| Power grommets | `PDC019B` × 2 | Black, USB-equipped |

**Chair — Herman Miller Embody Gaming**

| Spec | Value |
| ---- | ----- |
| Frame / base | Graphite |
| Upholstery | Sync — Nightfall Nova |
| Arms | Fully adjustable |
| Casters | 2.5" hard floor / carpet |

---

## Network gear

- **Router mesh** — ASUS ZenWiFi BE14000 (Wi-Fi 7), 3-node mesh:
  - Switch closet (downstairs)
  - Main floor
  - Top-floor office (this room) — uplinks the Aruba switch below
- **Switch** — Aruba Instant On 24-port, in the office, uplinks the workstation
  and anything else wired in here
- **WAN** — Spectrum cable (primary); Starlink configured as backup on the
  router for automatic failover when Spectrum drops

---

## UPS

None currently. **TODO** — add one. Once installed, list make/model and the
devices plugged into it.

---

## Lighting

None currently — no smart bulbs, key lights, or bias lighting.

---

## Other

No control surfaces, MIDI gear, NAS, 3D printer, or smart appliances tracked
here.

---

## References

Original purchase notes are in `stuff.txt` at the repo root. Linked product
pages from those notes are **reference only** — pricing and availability may
have changed since purchase. FedEx tracking numbers from the desk order have
been omitted here as they're identifying and add no value to the system
baseline; the originals remain in `stuff.txt`.
