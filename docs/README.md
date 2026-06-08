# docs/ — the real (sanitized) snippets

These are the actual config files driving the ensemble described in the
[root README](../README.md), lightly sanitized. **No secrets, tokens, IPs, or
API keys.** Standard Termux paths (`/data/data/com.termux/...`) are kept as-is —
they're identical on every Termux install, not device-specific.

Two execution contexts, don't mix them up:

| File | Runs in | Goes to |
|---|---|---|
| [`tmux.conf`](tmux.conf) | **proot Debian** | `~/.tmux.conf` (inside the rootfs) |
| [`bashrc-gordo.sh`](bashrc-gordo.sh) | **proot Debian** | append into `~/.bashrc` (inside the rootfs) |
| [`boot/start-sshd.sh`](boot/start-sshd.sh) | **Termux** (host) | `~/.termux/boot/` |
| [`boot/gordo-keepalive.sh`](boot/gordo-keepalive.sh) | **Termux** (host) | `~/.termux/boot/` |

## Install order

1. **In Termux (host):** install [Termux:Boot](https://github.com/termux/termux-boot)
   from F-Droid, then:
   ```sh
   mkdir -p ~/.termux/boot
   cp start-sshd.sh gordo-keepalive.sh ~/.termux/boot/
   chmod +x ~/.termux/boot/*.sh
   ```
   Also add the teleporter alias to the **Termux** `~/.bashrc`:
   ```sh
   alias claude="proot-distro login debian -- claude"
   ```

2. **In proot Debian** (`proot-distro login debian`):
   ```sh
   cp tmux.conf ~/.tmux.conf
   cat bashrc-gordo.sh >> ~/.bashrc      # appends the gordo functions
   ```

3. **Pick a mode:** `gordo-mode off` (low-power, default) or `gordo-mode on`
   (always-on). For real 24/7 with the screen off, set `on` **and reboot once**
   so the boot script engages the full wakelock with the flag present.

## How the pieces interlock

- `tmux.conf` + the `GORDO_TMUX` block in `bashrc-gordo.sh` → every door
  (Termux, Haven, SSH) lands in the one live `gordo` session.
- `gordo-mode` writes/removes the flag `~/.gordo_24_7` and manages a holder
  process (pid in `~/.gordo_holder.pid`) — **the flag is what `gordo-keepalive.sh`
  reads at boot**, which is why the switch survives reboots.
- `gordo-fix` enforces the f2fs rule: it clones a `/sdcard` repo onto `/root`
  with `--no-hardlinks` so git stops hitting fuse's broken hardlinks/symlinks.

## Caveats (same as root README)

- proot has no real init: `gordo` lives while ≥1 proot connection exists, or
  while the holder sustains it (mode `on`).
- Full wakelock (screen off for hours) only fully engages from a **boot with the
  flag set** — `gordo-mode on` live survives until deep sleep.
- Paths/UIDs are illustrative of one device (MediaTek, aarch64); yours differ.
- `start-sshd.sh` is the operator's own host-side script — shown for completeness.

## Attribution

The only original material here is the small "gordo" glue (the `gordo-mode` /
`gordo-fix` functions, the `.tmux.conf` tweaks, and the boot scripts) — and even
that just orchestrates third-party tools. Debian, Claude/Claude Code, Termux,
proot-distro, link2symlink, tmux and f2fs belong to their respective authors and
are not claimed here. See the [root README attribution section](../README.md#attribution--what-is-and-isnt-mine).
