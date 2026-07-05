#!/usr/bin/env bash
# Emit a status-line segment naming every session with a pending BELL alert
# (a Claude Code Notification hook fired there). Empty when none.
#
# Background colour reflects the *nature* of the notification, which
# claude-notify.sh records in ~/.config/tmux/state/claude-alert-<session>:
#   perm  needs your permission   -> red    bg=#fb4934  (blocking)
#   wait  waiting for your input  -> yellow bg=#fabd2f  (your turn)
#   info  everything else         -> aqua   bg=#83a598  (informational)
# An alert with no state file falls back to yellow. State files for sessions
# that are no longer alerting are swept so a stale colour can't haunt the bar.
#
# Icon = Nerd Font nf-fa-bell (U+F0F3). To change it, swap the octal UTF-8
# bytes below (portable across bash versions, unlike \u escapes):
#   U+F0F3  bell (filled)      \357\203\263
#   U+F0A2  bell (outline)     \357\202\242
icon=$(printf '\357\203\263')
state_dir="$HOME/.config/tmux/state"

tmux list-sessions -F '#{session_name}' 2>/dev/null | while IFS= read -r s; do
  safe=$(printf '%s' "$s" | tr -c 'A-Za-z0-9._-' '_')
  # Check if any per-window alert file exists for this session.
  urgent=
  for f in "$state_dir/claude-alert-${safe}"-*; do
    [ -f "$f" ] || continue
    c=$(cat "$f" 2>/dev/null)
    case "$c" in
      perm) urgent=perm; break ;;
      wait) urgent=wait ;;
      info) [ -z "$urgent" ] && urgent=info ;;
    esac
  done
  [ -z "$urgent" ] && continue
  case "$urgent" in
    perm) bg='#fb4934' ;;   # red    - needs permission
    info) bg='#83a598' ;;   # aqua   - informational
    *)    bg='#fabd2f' ;;   # yellow - waiting / unknown
  esac
  printf ' #[fg=#282828,bg=%s,bold]  %s %s  #[default]' "$bg" "$icon" "$s"
done
