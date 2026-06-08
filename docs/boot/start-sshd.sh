#!/data/data/com.termux/files/usr/bin/sh
# ~/.termux/boot/start-sshd.sh   (runs in TERMUX, via the Termux:Boot app)
# Keep sshd alive after reboot so the SSH door (port 8022) reopens by itself —
# this is how an operator laptop reattaches to the phone after a restart.
termux-wake-lock
sv-enable sshd 2>/dev/null
. $PREFIX/etc/profile.d/start-services.sh 2>/dev/null
sleep 3
pgrep -x sshd >/dev/null || $PREFIX/bin/sshd
