#!/usr/bin/env bash
# Track Claude Code session state on tmux panes, for pane-border and window-list colors.
#
#   tmux-state.sh hook <working|waiting|done|resume|clear>   from a Claude hook (hook JSON on stdin)
#   tmux-state.sh viewed <window_id>                         from tmux, when a window comes into view
#   tmux-state.sh next <pane_id>                             jump to the pane that has waited longest
#   tmux-state.sh wrap <verdict>                             from the wrap skill: record this session's verdict
#
# Pane option @claude_state holds working, waiting (on you) or done (finished, not yet seen), and
# @claude_since when it was set. Window option @claude_win holds the most urgent state among the
# window's panes, waiting > done > working; it has its own name because #{@claude_state} in a
# window format would read the window's active pane first.
#
# done is never set on a pane already on screen, and clears when its window comes into view.
# waiting stays until Claude moves on (a prompt, an approved tool call, or the turn ending).
#
# Pane option @claude_wrap holds the session's last /wrap verdict: quit (safe to quit or
# superseded), you (waiting on you), parked or progress. Unlike done, it survives being seen,
# and clears on the session's next prompt. Window option @claude_wrap_win holds the most urgent
# verdict among the window's panes, you > progress > parked > quit.

command -v tmux >/dev/null && tmux info >/dev/null 2>&1 || exit 0

# Recompute @claude_win for the window holding $1 (a pane or window id).
rollup() {
  local states w=
  states=$(tmux list-panes -t "$1" -F '#{@claude_state}' 2>/dev/null) || return
  case $states in
    *waiting*) w=waiting ;;
    *done*) w=done ;;
    *working*) w=working ;;
  esac
  if [[ -n $w ]]; then tmux set -w -t "$1" @claude_win "$w"; else tmux set -wu -t "$1" @claude_win; fi
  states=$(tmux list-panes -t "$1" -F '#{@claude_wrap}') w=
  case $states in
    *you*) w=you ;;
    *progress*) w=progress ;;
    *parked*) w=parked ;;
    *quit*) w=quit ;;
  esac
  if [[ -n $w ]]; then tmux set -w -t "$1" @claude_wrap_win "$w"; else tmux set -wu -t "$1" @claude_wrap_win; fi
}

set_state() {
  if [[ -n $2 ]]; then
    tmux set -p -t "$1" @claude_state "$2" \; set -p -t "$1" @claude_since "$(date +%s)"
  else
    tmux set -pu -t "$1" @claude_state \; set -pu -t "$1" @claude_since
  fi
  rollup "$1"
}

# The panes showing session $1. eow --tmux tags the viewer pane of a background session with the
# session's short id, since background sessions run outside tmux and have no TMUX_PANE.
find_panes() {
  local p
  p=$(tmux list-panes -a -F '#{pane_id} #{@claude_session}' |
    awk -v s="$1" '$2 != "" && index(s, $2) == 1 { print $1 }')
  echo "${p:-${TMUX_PANE:-}}"
}

case $1 in
  hook)
    sid=$(jq -r '.session_id // empty' 2>/dev/null)
    for pane in $(find_panes "$sid"); do
      cur=$(tmux display -p -t "$pane" '#{@claude_state}' 2>/dev/null) || continue
      # A new prompt or the session ending makes the last verdict stale.
      [[ $2 == working || $2 == clear ]] && tmux set -pu -t "$pane" @claude_wrap
      case $2 in
        working) set_state "$pane" working ;;
        waiting) set_state "$pane" waiting ;;
        resume) [[ $cur == waiting ]] && set_state "$pane" working ;;
        clear) set_state "$pane" '' ;;
        done)
          if [[ $(tmux display -p -t "$pane" '#{&&:#{window_active},#{session_attached}}') == 1 ]]; then
            set_state "$pane" ''
          else
            set_state "$pane" done
          fi ;;
      esac
    done ;;

  viewed)
    for p in $(tmux list-panes -t "$2" -F '#{?#{==:#{@claude_state},done},#{pane_id},}'); do
      tmux set -pu -t "$p" @claude_state \; set -pu -t "$p" @claude_since
    done
    rollup "$2" ;;

  next)
    # Oldest waiting pane first, then oldest done; skip the pane we are in.
    target=$(tmux list-panes -a -F '#{@claude_state} #{@claude_since} #{pane_id}' |
      awk -v cur="$2" '$3 != cur && $1 == "waiting" { print 0, $2, $3 }
                       $3 != cur && $1 == "done"    { print 1, $2, $3 }' |
      sort -k1,1n -k2,2n | awk 'NR == 1 { print $3 }')
    if [[ -z $target ]]; then
      tmux display-message "No Claude sessions waiting"
    else
      tmux switch-client -t "$target" \; select-window -t "$target" \; select-pane -t "$target"
    fi ;;

  wrap)
    # Run from a Claude session's Bash tool, which has the session id and, inside tmux, TMUX_PANE.
    case $2 in
      'SAFE TO QUIT'|SUPERSEDED|quit) v=quit ;;
      'WAITING ON YOU'|you) v=you ;;
      'IN PROGRESS'|progress) v=progress ;;
      PARKED|parked) v=parked ;;
      *) echo "tmux-state.sh wrap: unknown verdict: $2" >&2; exit 1 ;;
    esac
    for pane in $(find_panes "${CLAUDE_CODE_SESSION_ID:-}"); do
      tmux set -p -t "$pane" @claude_wrap "$v"
      rollup "$pane"
    done ;;
esac
exit 0
