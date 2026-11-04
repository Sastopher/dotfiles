#!/usr/bin/env bash
# Ask specific Claude sessions to run /wrap, by typing it into their tmux panes.
#
#   wrap-send [--check] [--force] [--dry-run] [--notify] <target>...   target: session name, pane id (%56) or tmux target (main:4.2)
#   wrap-send --pick [--check] [--exclude PANE] fzf picker over Claude panes (Tab marks several)
#
# Sends "/wrap" (or "/wrap check" with --check; alt-c in the picker). A session busy with a turn
# queues it and runs it next. A pane whose @claude_state is "waiting" has a dialog open, where
# typed keys could answer it, so it is skipped unless --force. Background sessions with no
# pane can't be reached this way: `claude attach <name>`, or ask a Claude session to SendMessage.
# --notify reports in the tmux message line instead of stdout (for key bindings: prefix + W).

set -uo pipefail

mode=wrap force= pick= exclude= dry= notify=
targets=()
while [[ $# -gt 0 ]]; do
  case $1 in
    --check) mode=check; shift ;;
    --force) force=1; shift ;;
    --dry-run) dry=1; shift ;;
    --notify) notify=1; shift ;;
    --pick) pick=1; shift ;;
    --exclude) exclude=$2; shift 2 ;;
    -h|--help) sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) targets+=("$1"); shift ;;
  esac
done

# Claude panes: "<pane_id>\t<name>\t<location>\t<state>\t<quiet>". Claude runs as a process
# named after its version (2.1.316) and titles its pane "<glyph> <session name>".
claude_panes() {
  local now; now=$(date +%s)
  tmux list-panes -a -F '#{pane_id}	#{pane_current_command}	#{pane_title}	#{session_name}:#{window_index}.#{pane_index}	#{@claude_state}	#{window_activity}' |
    awk -F'\t' -v now="$now" -v ex="$exclude" '
      $1 != ex && ($2 ~ /^[0-9]+\.[0-9]+\.[0-9]+$/ || $2 == "claude") {
        name = $3; sub(/^[^A-Za-z0-9]+ */, "", name)
        q = now - $6
        quiet = q >= 86400 ? int(q / 86400) "d" : q >= 3600 ? int(q / 3600) "h" : int(q / 60) "m"
        printf "%s\t%s\t%s\t%s\t%s\n", $1, name, $4, ($5 == "" ? "idle" : $5), quiet
      }'
}

# Resolve one target to a pane id: pane id or tmux target as given, else an exact session
# name, else a unique name prefix.
resolve() {
  local t=$1 rows hits
  if [[ $t == %* || $t == *:* ]]; then
    tmux display -p -t "$t" '#{pane_id}' 2>/dev/null && return
    echo "wrap-send: no pane $t" >&2; return 1
  fi
  rows=$(claude_panes)
  hits=$(awk -F'\t' -v t="$t" '$2 == t { print $1 }' <<<"$rows")
  [[ -z $hits ]] && hits=$(awk -F'\t' -v t="$t" 'index($2, t) == 1 { print $1 }' <<<"$rows")
  case $(grep -c . <<<"$hits") in
    1) echo "$hits" ;;
    0) echo "wrap-send: no tmux pane shows a session named $t (background? try: claude attach $t)" >&2; return 1 ;;
    *) echo "wrap-send: $t matches several panes:" >&2
       awk -F'\t' -v t="$t" 'index($2, t) == 1 { print "  " $3 "  " $2 }' <<<"$rows" >&2; return 1 ;;
  esac
}

say() { if [[ -n $notify ]]; then tmux display-message "wrap: $*"; else echo "$*"; fi; }

send() {
  local pane=$1 cmd state where
  cmd=$(tmux display -p -t "$pane" '#{pane_current_command}')
  where=$(tmux display -p -t "$pane" '#{session_name}:#{window_index}.#{pane_index} #{pane_title}')
  if [[ ! $cmd =~ ^[0-9]+\.[0-9]+\.[0-9]+$ && $cmd != claude ]]; then
    say "skip  $where: not a Claude session ($cmd)"; return
  fi
  state=$(tmux display -p -t "$pane" '#{@claude_state}')
  if [[ $state == waiting && -z $force ]]; then
    say "skip  $where: a dialog is open (answer it first, or --force)"; return
  fi
  local text=/wrap; [[ $mode == check ]] && text="/wrap check"
  [[ -n $dry ]] && { say "would send  $where: $text"; return; }
  # Typed text arriving in one burst reads as a paste; a pause lets Enter submit it.
  tmux send-keys -t "$pane" -l "$text"
  sleep 0.3
  tmux send-keys -t "$pane" Enter
  say "sent  $where: $text"
}

if [[ -n $pick ]]; then
  out=$(claude_panes | sort -t$'\t' -k2,2 |
    fzf --multi --delimiter='\t' --with-nth=2,3,4,5 --expect=alt-c \
        --header='Enter: /wrap   alt-c: /wrap check   Tab: mark several' \
        --preview='tmux capture-pane -p -e -t {1} | grep -v "^[[:space:]]*$" | tail -40' \
        --preview-window=right,60%,wrap --ansi) || exit 0
  key=$(head -1 <<<"$out")
  [[ $key == alt-c ]] && mode=check
  panes=$(tail -n +2 <<<"$out" | cut -f1)
  for p in $panes; do send "$p"; done
  sleep 1.5   # leave the result on screen before the popup closes
  exit 0
fi

[[ ${#targets[@]} -gt 0 ]] || { sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }
rc=0
for t in "${targets[@]}"; do
  if p=$(resolve "$t" 2>&1); then send "$p"; else say "$p"; rc=1; fi
done
exit $rc
