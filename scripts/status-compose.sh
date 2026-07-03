#!/usr/bin/env bash
# Declutter the 'powerline/default/gray' themepack status bar:
#   left  = session name + window:pane index  (username segment removed)
#   right = [Claude cross-session alerts] + time
# Deferred + self-healing (~10s) because TPM sources the themepack
# asynchronously and would otherwise clobber these. `once` = apply a single
# time (used for immediate reload/verification).

# Left: themepack segments minus the #(whoami) block; the 245->235 colour
# transition is stitched back together where whoami used to sit.
left="#[fg=colour233,bg=colour245,bold] #S #[fg=colour245,bg=colour235,nobold]#[fg=colour240,bg=colour235] #I:#P #[fg=colour235,bg=colour233,nobold]"

# Right: alert segment (empty unless a Claude is waiting) + one bright time
# block that mirrors the left session block.
right="#(~/.config/tmux/scripts/claude-alerts.sh)#[fg=colour233,bg=colour245,bold] %H:%M:%S #[default]"

apply() {
  tmux set -g status-left-length 60
  tmux set -g status-right-length 150
  [ "$(tmux show -gqv status-left)"  = "$left"  ] || tmux set -g status-left  "$left"
  [ "$(tmux show -gqv status-right)" = "$right" ] || tmux set -g status-right "$right"
}

if [ "$1" = "once" ]; then apply; exit 0; fi
for _ in $(seq 1 10); do apply; sleep 1; done
