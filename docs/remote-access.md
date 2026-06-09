# Remote access that survives WiFi ↔ 4G/5G

The phone-as-brain runs **locally**, so Claude/`gordo` work on any data connection
already. What does *not* work out of the box is **reaching the phone from another
machine over cellular**: on WiFi you hit the phone's LAN IP, but on 4G/5G the phone
sits behind the carrier's **CGNAT** — no publicly reachable address.

This is solved in three layers, each covering a different failure:

| Layer | Solves | Tool |
|---|---|---|
| Reachable on any network | escapes 4G/5G CGNAT | **Tailscale** (stable IP via NAT traversal) |
| Connection that roams | WiFi↔cellular handoff, dead zones | **mosh** (UDP, resumes by itself) |
| Session that never dies | app/Termux killed | **tmux `gordo`** (+ the 24/7 holder) |

> **Where each piece lives.** Termux's `sshd` (port `8022`) has no `ForceCommand`, so
> an incoming SSH lands in the **Termux** shell (not proot). Therefore `mosh-server`
> must be installed in **Termux**, not inside the Debian rootfs.

---

## Setup

### 1) On the phone — Termux (open a Termux tab, not proot)
```sh
pkg update && pkg install mosh
```
Install the **Tailscale Android app** (F-Droid or Play Store — uses Android's
VpnService, **no root needed**) and log in.

> The Termux `tailscale` package runs userspace-only without a TUN device and is
> finicky; the Android app is the robust path. `sshd` is already kept alive at boot
> by your Termux:Boot script — nothing to change there.

### 2) On the operator machine (laptop/desktop)
Install Tailscale (same account → same tailnet) and `mosh`, then:
```sh
mosh --ssh="ssh -p 8022" <termux-user>@<phone-tailscale-ip>
```
- `<phone-tailscale-ip>` is the phone's stable Tailscale address — reachable over
  **WiFi, 4G and 5G** alike.
- `mosh` uses UDP 60000–61000 (Tailscale carries UDP) and **resumes the session by
  itself** when you switch WiFi↔cellular or pass through a dead zone.

### 3) Once you're on the phone
```sh
tmux attach -t gordo     # (or just opening a shell lands in gordo via ~/.bashrc)
claude                   # alias → proot Debian
```

---

## Honest caveats

- `mosh-server` lives in **Termux**. If Android kills Termux, that mosh connection
  drops — but **`gordo` in proot persists**, so you reconnect with mosh + `tmux
  attach` and resume exactly where you were. The 24/7 wakelock reduces the chance
  Android kills it.
- Tailscale's app is a system VPN (VpnService); it coexists with normal traffic.
- Some carriers hand out a public IPv6 on cellular, which *can* allow direct reach
  without Tailscale — but it's carrier-dependent and fragile. Tailscale is the
  reliable answer.
- Placeholders above (`<termux-user>`, `<phone-tailscale-ip>`) are yours to fill —
  never commit your real Tailscale IP, hostnames, or keys to a public repo.
