#!/data/data/com.termux/files/usr/bin/sh
# ~/.termux/boot/gordo-keepalive.sh   (runs in TERMUX, via the Termux:Boot app)
# Switch 24/7 for Gordo — acts ONLY if the flag ~/.gordo_24_7 exists.
# No flag → script exits and the system stays in low-power. The flag is the
# master switch that survives reboots.
[ -f "$HOME/.gordo_24_7" ] || exit 0

# Always-on mode: wakelock + a live proot that sustains the tmux 'gordo' session.
# SELF-HEALING holder (2026-06-19): instead of tail -f, a loop that recreates
# 'gordo' if tmux ever dies. Keeps the process name 'gordo_holder' (detected by
# gordo-mode status). Without this, a tmux crash after boot left the holder
# orphaned: mode alive, session dead.
termux-wake-lock
proot-distro login debian -- bash -lc \
  'exec -a gordo_holder bash -c "echo \$\$ > /root/.gordo_holder.pid; while :; do tmux has-session -t gordo 2>/dev/null || tmux new-session -d -s gordo 2>/dev/null; sleep 30; done"' &
