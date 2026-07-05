#!/bin/zsh
# claude-fzf.sh — fzf popup: switch to windows where Claude is running.
# Annotates windows with pending notification state (PERM/WAIT/INFO) and
# sorts alerted windows to the top.

state_dir="$HOME/.config/tmux/state"

# Map pane PIDs -> "session:window_index: window_name"
declare -A pane_to_win
while IFS= read -r line; do
    pid=${line%% *}
    win=${line#* }
    pane_to_win[$pid]="$win"
done < <(tmux list-panes -a -F '#{pane_pid} #{session_name}:#{window_index}: #{window_name}')

# For each claude process, walk up PPIDs until we hit a known pane PID.
declare -A found_wins
for cpid in $(pgrep -af "claude" 2>/dev/null); do
    pid=$cpid
    while [[ "$pid" -gt 1 ]]; do
        if [[ -n "${pane_to_win[$pid]}" ]]; then
            found_wins["${pane_to_win[$pid]}"]=1
            break
        fi
        pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
        [[ -z "$pid" ]] && break
    done
done

if [[ ${#found_wins[@]} -eq 0 ]]; then
    tmux display-message "No Claude windows found"
    exit 0
fi

# Exclude the current window.
current_win=$(tmux display-message -p '#{session_name}:#{window_index}')

# Annotate with notification state; put alerted windows first.
alerted=""
running=""
for win_str in "${(Qk)found_wins[@]}"; do
    win_key=$(echo "$win_str" | sed 's/: .*//')
    [[ "$win_key" == "$current_win" ]] && continue

    session=$(echo "$win_key" | sed 's/:.*//')
    window_index=$(echo "$win_key" | sed 's/.*://')
    safe=$(printf '%s' "$session" | tr -c 'A-Za-z0-9._-' '_')
    state_file="$state_dir/claude-alert-${safe}-${window_index}"

    if [[ -f "$state_file" ]]; then
        cat=wait
        [[ -f "$state_file" ]] && cat=$(cat "$state_file" 2>/dev/null)
        case "$cat" in
            perm) label="[PERM]" ;;
            info) label="[INFO]" ;;
            *)    label="[WAIT]" ;;
        esac
        alerted+="$label $win_str"$'\n'
    else
        running+="       $win_str"$'\n'
    fi
done

full_list="${alerted}${running}"

if [[ -z "$full_list" ]]; then
    tmux display-message "No other Claude windows found"
    exit 0
fi

# Show popup and switch on selection.
target_origin=$(printf "%s" "$full_list" | grep -v '^$' | \
    fzf-tmux -p "50%,50%" \
    --no-preview \
    --header="Claude windows — [PERM]/[WAIT]/[INFO] = pending alert")

[[ -z "$target_origin" ]] && exit

# Strip the label prefix to recover "session:window_index: window_name".
window_str=$(echo "$target_origin" | sed 's/^\[[A-Z]*\] //' | sed 's/^       //')
target=$(echo "$window_str" | sed 's/: .*//')
session=$(echo "$target" | sed 's/:.*//')
tmux switch-client -t "$session"
tmux select-window -t "$target"
