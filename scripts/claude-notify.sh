#!/usr/bin/env bash
# Claude Code Notification hook.
#
# A raw tmux BELL is typeless — the status bar can't tell *why* Claude rang.
# So before ringing, we read the hook payload (JSON on stdin), classify the
# notification by its `message`, and stash the category in a per-session state
# file. claude-alerts.sh reads that file to colour the alert by its nature:
#
#   perm  needs your permission   -> red    (blocking, come right here)
#   wait  waiting for your input  -> yellow (idle, your turn)
#   info  everything else         -> aqua   (informational)
#
# Then we ring the bell exactly as the old inline hook did, so tmux still
# flags the session alert and cross-session surfacing keeps working.

set -u

# Payload arrives on stdin; .message holds the human-readable reason.
payload=$(cat 2>/dev/null)
msg=$(printf '%s' "$payload" | jq -r '.message // empty' 2>/dev/null)

case "$msg" in
*[Pp]ermission*|*[Aa]pprove*)               cat=perm ;;
*[Ww]aiting*|*[Ii]dle*[Nn]eeds your input*) cat=wait ;;
*)                                          cat=info ;;
esac

# Without a pane we can't attribute the alert to a session or ring a tty.
[ -n "${TMUX_PANE:-}" ] || exit 0

# If you're already staring at the pane that triggered this, there's nothing to
# surface — don't write state, don't ring. #{session_attached} is a client count
# (>=1 => some client is showing this pane's session); together with the window
# and pane being the active ones, that means this exact pane is on screen right
# now. Only alert when the notification would otherwise go unseen.
focus=$(tmux display-message -p -t "$TMUX_PANE" \
  '#{session_attached} #{window_active} #{pane_active}' 2>/dev/null)
set -- $focus
if [ "${1:-0}" -ge 1 ] 2>/dev/null && [ "${2:-0}" = "1" ] && [ "${3:-0}" = "1" ]; then
  exit 0
fi

session=$(tmux display-message -p -t "$TMUX_PANE" '#{session_name}' 2>/dev/null)
tty=$(tmux display-message -p -t "$TMUX_PANE" '#{pane_tty}' 2>/dev/null)

# Persist the category, keyed by a filesystem-safe session name (same
# sanitising claude-alerts.sh applies when it reads the file back).
if [ -n "$session" ]; then
  state_dir="$HOME/.config/tmux/state"
  mkdir -p "$state_dir" 2>/dev/null
  safe=$(printf '%s' "$session" | tr -c 'A-Za-z0-9._-' '_')
  window=$(tmux display-message -p -t "$TMUX_PANE" '#{window_index}' 2>/dev/null)
  printf '%s' "$cat" > "$state_dir/claude-alert-${safe}-${window}" 2>/dev/null
fi

# Ring the bell so tmux sets the session alert (mirrors the old inline hook).
tmux set-window-option -t "$TMUX_PANE" monitor-bell on 2>/dev/null
[ -n "$tty" ] && printf '\a' > "$tty" 2>/dev/null
# Repaint the status bar immediately so the alert segment appears now, not at
# the next status-interval tick.
tmux refresh-client -S 2>/dev/null
true
