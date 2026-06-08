# claude-android-proot-f2fs

**Claude Code running 100% locally on an Android phone** — as the *brain*, not a thin client to a server.
Debian 13 in `proot-distro` over Termux, with the working tree on **f2fs (real Linux FS)**, hardlinks rescued by **link2symlink**, and a persistent **tmux** session with a 24/7 ↔ low-power switch and boot autostart.

> Most "Claude Code on mobile" guides make the phone a *terminal* that SSHes into a desktop or cloud box that does the real work. This is the inverse: **the phone is the machine.** No server, no Tailscale dependency, no remote box. When I searched, the individual pieces were documented by different people — the *integrated whole* was not. This repo documents the ensemble as a unit.

---

## TL;DR — why this is the hard path (and why it usually breaks)

| Problem on Android | What breaks | Fix used here |
|---|---|---|
| Claude binary is a glibc Linux ELF | Termux is Bionic libc → won't run natively past the JS-entrypoint era | run it **inside `proot-distro` Debian** (real glibc) |
| Binary is ~243 MB and Android blocks hardlinks for unprivileged apps | install/exec of the binary fails | **link2symlink (`.l2s`)** intercepts syscalls and emulates hardlinks inside the rootfs |
| Working tree on `/sdcard` | fuse storage: `symlink → Permission denied`, `hardlink → Operation not permitted`, `chmod 600 → 660`, git "dubious ownership" | put the **working tree on `/root` (f2fs)** — real Linux FS; `.l2s` only works inside the rootfs anyway |
| Close the app / screen locks | session dies | persistent **tmux `gordo`** session; every interactive shell attaches to it |
| Want it alive with the phone in your pocket | proot has no real init | **24/7 switch** (flag + holder process) + **Termux:Boot** autostart with wakelock |

---

## Architecture

```
🖥️  MacBook Pro 2012 / Kali        ← command post (operator, SSH only)
        │ ssh -p 8022  (Termux's sshd)
        ▼
📱  Android phone  (MediaTek, internal storage = f2fs)
     │
     ├─ Termux ──▶ sshd :8022 ─┐
     │                          ├─▶  proot-distro login debian  ──▶  Debian 13 (trixie, aarch64)
     └─ Haven (SSH/VNC/SFTP) ──┘                                        └─ .l2s ──▶ claude binary (~243 MB)
                                                                        └─ tmux 'gordo' (persistent)
                                                                        └─ working tree on /root  (f2fs)
☁️  GitHub  ← the only copy that survives a wipe
```

One rootfs, two doors (Termux directly, or Haven over the network). Both are unprivileged user-space apps — no root, Play Integrity stays intact.

---

## The stack, layer by layer

### 1. Base — Termux + proot-distro Debian
```
Termux (Android, Bionic libc, f2fs)
  └─ proot-distro login debian        # transparent login via alias
       └─ Debian 13 (trixie), aarch64, kernel 6.17.0-PRoot-Distro
            └─ .l2s (link2symlink) → runs the 243 MB claude binary
```

A "teleporter" alias in `~/.bashrc` hides the proot step:
```bash
alias claude="proot-distro login debian -- claude"
```
You open a window, type `claude`, and you're inside Debian — you never see `proot-distro login`.

### 2. link2symlink — the hardlink rescue
Android forbids hardlinks for unprivileged apps, and git/object-stores depend on them internally. `proot-distro` stores blobs under `/.l2s/` and intercepts syscalls to emulate hardlinks. Relevant env inside the rootfs:
```
CLAUDE_CODE_EXECPATH=/.l2s/.l2s.claudeXXXX.XXXX
PROOT_L2S_DIR=.../proot-distro/containers/debian/rootfs/.l2s
```
**The three things that hold the whole setup up: the alias + the Debian rootfs + the `.l2s` folder.** Back those up and you can rebuild.

### 3. f2fs, never /sdcard — "the Android ghosts"
git, `gh`, and Copilot CLI "randomly" misbehaving on Android have one root cause: the working tree living on `/sdcard`, which is **fuse** (emulated storage), not a real Linux FS. Hard evidence:

| Op on `/sdcard` (fuse) | Result | Op on `/root` (f2fs) | Result |
|---|---|---|---|
| `symlink` | `Permission denied` | `symlink` | ✅ |
| `hardlink` | `Operation not permitted` | `hardlink` | ✅ |
| `chmod 600` | silently stays `660` | `chmod 600` | ✅ 600 |
| ownership | forced Media UID → git "dubious ownership" | ownership | `root:root` |

**Rule:** every *live* repo lives on f2fs (`/root/<repo>`). `/sdcard` is backup/transfer only. Migrate without losing the backup:
```bash
git clone --no-hardlinks /sdcard/<repo> /root/<repo>
git -C /root/<repo> remote set-url origin <github-url>
```

### 4. Persistence — tmux `gordo`
- `~/.tmux.conf`: mouse/touch on, 50k history, splits `|`/`-`, reload on `prefix r`.
- `~/.bashrc` block: every interactive shell runs `tmux new-session -A -s gordo`, so Termux *and* Haven always land in the same live session. Detach `Ctrl+b d`; reattach by just reopening the app.

### 5. 24/7 ↔ low-power switch (`gordo-mode`)
A bash function in `~/.bashrc`:
- `gordo-mode on` → 🟢 always-on: writes flag `~/.gordo_24_7` and launches a holder (`setsid bash … tail -f /dev/null`, pid in `~/.gordo_holder.pid`) that keeps proot+gordo alive even with every door closed.
- `gordo-mode off` → 🔵 low-power (default): removes flag, kills holder; gordo sleeps on disconnect to save battery.
- `gordo-mode status` → mode + holder (detected by **pidfile**, not `pgrep` — `pgrep -f` self-matched = false positive).

### 6. Boot autostart (Termux:Boot, `~/.termux/boot/`)
- `start-sshd.sh` — wakelock + keeps Termux's sshd alive after reboot (door for SSH on `:8022`).
- `gordo-keepalive.sh` — **only** acts if the flag `~/.gordo_24_7` exists; then wakelock + `proot-distro login debian -- … tmux new -d -s gordo`. The flag is the master switch that survives reboots.

---

## Honest caveats (no magic claims)

- **proot has no real init.** `gordo` lives only while ≥1 proot connection exists, *or* while the holder sustains it (mode `on`).
- **Wakelock.** `gordo-mode on` live survives until the phone hits deep sleep; the *full* wakelock (screen off for hours) only fully engages from a **boot with the flag set**. For real 24/7 with the phone pocketed: leave it `on` and reboot once.
- **`du` lies in the rootfs** — symlinks double-count (shows ~870 MB, real data ~550 MB).
- **Reachability.** From inside proot you can't see Termux/Haven/Kali — Android isolates each app's sandbox.
- This documents *one* working ensemble on *one* device family (MediaTek, aarch64). Treat paths/UIDs as illustrative, not universal.

---

## Backup / restore (the part people get wrong)

The phone clone is **not** a backup of your PCs — cloning to the phone ≠ backing up a desktop's local-only work. GitHub is the only copy that survives a wipe. For the *environment itself*:

```bash
# from inside proot, tar the real container dirs to the host rootfs path:
tar czf debian_rootfs_<stamp>.tar.gz -C <rootfs> \
  --warning=no-file-changed --ignore-failed-read \
  .l2s bin boot etc home lib media opt root sbin srv usr var
# excludes Android bind mounts (data sdcard system vendor apex ...)
```
Restore **inside proot** (`proot-distro login debian -- tar xzf … -C /`) so link2symlink re-applies hardlinks on f2fs. `proot-distro backup debian` (run from Termux, not as root) is the higher-fidelity alternative. Keep the old rootfs as `_ROJO_` — never `rm`.

---

## Not included / security

- **No secrets, tokens, IPs, or API keys** are in this repo by design.
- Paths and UIDs shown are illustrative of one device; yours will differ.
- This is a documentation repo (the *map*), not a one-click installer.

---

## Prior art (the scattered pieces)

The components exist in the wild — written by different people, for the *opposite* (phone-as-client) topology:

- Native-on-Android workarounds: `ferrumclaudepilgrim/claude-code-android`, `eduterre/claude-code-termux`, `Ishabdullah/claude-code-termux`
- The glibc-binary breakage: anthropics/claude-code issue #50270
- Phone-as-thin-client setups: skeptrune (Termux + Tailscale), rogs (mosh + tmux + ntfy), greatai.dev (Tailscale + Termux)

What was missing — and what this repo is — is the **fully-local, phone-as-brain ensemble**: proot **Debian** + link2symlink + **f2fs working tree on purpose** + persistent gordo tmux + 24/7 switch + boot autostart, as one documented unit.

---

*Maintained by [ART449](https://github.com/ART449). Built and documented from inside the phone it describes.*
