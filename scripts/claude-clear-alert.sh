#!/bin/zsh
# Clear the per-window Claude notification state.
#
# Two callers:
#   1. Claude Code UserPromptSubmit hook (TMUX_PANE is set) — always clear
#      the specific window's alert.
#   2. tmux after-select-window hook (no TMUX_PANE) — clear only if the
#      newly focused window hosts a Claude process.

state_dir="$HOME/.config/tmux/state"

if [[ -n "${TMUX_PANE:-}" ]]; then
    session=$(tmux display-message -p -t "$TMUX_PANE" '#{session_name}' 2>/dev/null)
    window=$(tmux display-message -p -t "$TMUX_PANE" '#{window_index}' 2>/dev/null)
    [[ -z "$session" || -z "$window" ]] && exit 0
    safe=$(printf '%s' "$session" | tr -c 'A-Za-z0-9._-' '_')
    rm -f "$state_dir/claude-alert-${safe}-${window}" 2>/dev/null
else
    # Values are passed as env vars by the tmux hook, expanded at fire time.
    [[ -z "${SESSION:-}" || -z "${WINDOW:-}" || -z "${PANE_PID:-}" ]] && exit 0
    safe=$(printf '%s' "$SESSION" | tr -c 'A-Za-z0-9._-' '_')
    state_file="$state_dir/claude-alert-${safe}-${WINDOW}"
    [[ -f "$state_file" ]] || exit 0

    # Only clear if a Claude process lives in the current pane.
    pane_pid=$PANE_PID
    for cpid in $(pgrep -af "claude" 2>/dev/null); do
        pid=$cpid
        while [[ $pid -gt 1 ]]; do
            if [[ $pid == $pane_pid ]]; then
                rm -f "$state_file"
                exit 0
            fi
            pid=$(ps -o ppid= -p $pid 2>/dev/null | tr -d ' ')
            [[ -z $pid ]] && break
        done
    done
fi
