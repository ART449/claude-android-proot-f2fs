# ============================================================================
# GORDO block for ~/.bashrc  (inside the proot Debian rootfs)
# Paste this into your Debian ~/.bashrc. Standard Termux paths are kept as-is
# (they are identical on every Termux install — not secrets).
# ============================================================================

# 1) Teleporter alias: type `claude`, land straight inside Debian's claude.
#    (Defined in the OUTER Termux ~/.bashrc, shown here for completeness.)
#    alias claude="proot-distro login debian -- claude"

# 2) gordo-fix: clone a repo off /sdcard (fuse — breaks git) onto /root (f2fs,
#    real Linux FS) and cd into it. Usage: gordo-fix <repo-name-in-/sdcard>
gordo-fix() {
  [ -z "$1" ] && { echo "usage: gordo-fix <repo-name-in-/sdcard>"; return 1; }
  git config --global --add safe.directory "/sdcard/$1/.git" 2>/dev/null
  git clone --no-hardlinks "/sdcard/$1" "/root/$1" && cd "/root/$1" \
    && echo "✅ clean copy on f2fs: $(pwd)  (remember: git remote set-url origin <github-url>)"
}

# 3) GORDO_TMUX: every interactive shell attaches to (or creates) session 'gordo',
#    so Termux AND Haven always land in the SAME live session. App dies → work
#    is still here waiting. Guards: only interactive, only when not already in tmux.
#    Escape hatch: open with GORDO_NOTMUX=1 for a plain shell that does NOT
#    auto-attach to gordo (e.g. `GORDO_NOTMUX=1 proot-distro login debian`).
if command -v tmux >/dev/null 2>&1 && [ -z "$TMUX" ] && [ -z "$GORDO_NOTMUX" ] && [[ $- == *i* ]]; then
  tmux new-session -A -s gordo
fi

# 4) GORDO_SWITCH: flip 24/7 <-> low-power on demand.
#    gordo-mode on      -> always-on: gordo stays alive even if you disconnect
#    gordo-mode off     -> low-power: gordo sleeps when all doors close (default)
#    gordo-mode status  -> show current mode (holder detected by PIDFILE, not pgrep)
gordo-mode() {
  local FLAG=/data/data/com.termux/files/home/.gordo_24_7
  local PID=/root/.gordo_holder.pid
  _gordo_holder_alive() { [ -f "$PID" ] && kill -0 "$(cat "$PID" 2>/dev/null)" 2>/dev/null; }
  case "$1" in
    on)
      touch "$FLAG"
      if _gordo_holder_alive; then
        echo "🟢 24/7 was already ON (holder alive)."
      else
        setsid bash -c 'echo $$ > /root/.gordo_holder.pid; while :; do tmux has-session -t gordo 2>/dev/null || tmux new-session -d -s gordo 2>/dev/null; sleep 30; done' </dev/null >/dev/null 2>&1 &
        echo "🟢 24/7 ON — gordo stays alive even if you close Haven/Termux (self-heals the session if tmux dies)."
        echo "   (Full wakelock with screen off engages from the NEXT boot.)"
      fi
      ;;
    off)
      rm -f "$FLAG"
      _gordo_holder_alive && kill "$(cat "$PID")" 2>/dev/null
      rm -f "$PID"
      echo "🔵 LOW-POWER ON — gordo sleeps once you close all doors (saves battery)."
      ;;
    status|"")
      [ -f "$FLAG" ] && echo "configured mode: 🟢 24/7" || echo "configured mode: 🔵 low-power"
      _gordo_holder_alive && echo "always-on holder: ALIVE (pid $(cat "$PID"))" || echo "always-on holder: asleep"
      tmux has-session -t gordo 2>/dev/null && echo "gordo session: alive ✅" || echo "gordo session: not running now"
      ;;
    *) echo "usage: gordo-mode [on|off|status]" ;;
  esac
}
