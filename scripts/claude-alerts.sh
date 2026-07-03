#!/usr/bin/env bash
# Emit a status-line segment naming every session with a pending BELL alert
# (a Claude Code Notification hook fired there). Empty when none.
#
# Icon = Nerd Font nf-fa-bell (U+F0F3). To change it, swap the octal UTF-8
# bytes below (portable across bash versions, unlike \u escapes):
#   U+F0F3  bell (filled)      \357\203\263
#   U+F0A2  bell (outline)     \357\202\242
#   U+F0F3  ""                 (default)
icon=$(printf '\357\203\263')
tmux list-sessions -F '#{session_name}' 2>/dev/null | while IFS= read -r s; do
  a=$(tmux display-message -p -t "$s" '#{session_alerts}' 2>/dev/null)
  case "$a" in
  # Powerline-style block: transparent (inherited) text on a Gruvbox Material
  # yellow background, padded. fg=default lets the text take the theme's
  # foreground instead of a forced colour. To tweak:
  #   dark/legible text -> fg=#282828 ; brighter gruvbox yellow -> bg=#fabd2f
  *'!'*) printf ' #[fg=#282828,bg=#fabd2f,bold]  %s %s  #[default]' "$icon" "$s" ;;
  esac
done
