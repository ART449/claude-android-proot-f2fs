#!/data/data/com.termux/files/usr/bin/sh
# ~/.termux/boot/gordo-keepalive.sh   (runs in TERMUX, via the Termux:Boot app)
# Switch 24/7 for Gordo — acts ONLY if the flag ~/.gordo_24_7 exists.
# No flag → script exits and the system stays in low-power. The flag is the
# master switch that survives reboots.
[ -f "$HOME/.gordo_24_7" ] || exit 0

# Always-on mode: wakelock + a live proot that sustains the tmux 'gordo' session.
termux-wake-lock
proot-distro login debian -- bash -lc \
  'tmux new-session -d -s gordo 2>/dev/null; exec -a gordo_holder tail -f /dev/null' &
