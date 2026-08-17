# ── Prompt ──────────────────────────────────────────────────────────────────
eval "$(starship init zsh)"

# ── Version manager ─────────────────────────────────────────────────────────
[ -f /opt/homebrew/opt/asdf/libexec/asdf.sh ] && . /opt/homebrew/opt/asdf/libexec/asdf.sh

# ── Aliases ─────────────────────────────────────────────────────────────────
alias ls="ls -G"
alias ll="ls -l"
alias la="ls -la"

alias vim="nvim"
alias g="git"

# ── Auto-attach tmux over SSH ───────────────────────────────────────────────
# Local terminals get tmux from Ghostty's `command =` setting instead.
if [[ -o interactive ]] && [[ -z "$TMUX" ]] && [[ -n "$SSH_CONNECTION" ]]; then
  tmux attach-session -t remote || tmux new-session -s remote
fi

# ── pnpm ────────────────────────────────────────────────────────────────────
export PNPM_HOME="$HOME/Library/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end

# ── Completion ──────────────────────────────────────────────────────────────
autoload -Uz compinit && compinit

autoload -U +X bashcompinit && bashcompinit
command -v terraform >/dev/null && complete -o nospace -C "$(command -v terraform)" terraform

# graphite: `gt completion` takes ~0.2s, so cache it instead of eval-ing at
# every shell start. Delete the cache file after upgrading gt to regenerate.
if command -v gt >/dev/null; then
  GT_COMPLETION="${XDG_CACHE_HOME:-$HOME/.cache}/gt-completion.zsh"
  [ -s "$GT_COMPLETION" ] || { mkdir -p "$(dirname "$GT_COMPLETION")"; gt completion > "$GT_COMPLETION"; }
  . "$GT_COMPLETION"
  unset GT_COMPLETION
fi

# ── PATH ────────────────────────────────────────────────────────────────────
export PATH="$HOME/.local/bin:$PATH"

# ── Per-project env (direnv) ────────────────────────────────────────────────
command -v direnv >/dev/null && eval "$(direnv hook zsh)"

# ── Machine-local overrides (never committed) ───────────────────────────────
# Work-specific env vars, tokens, internal tooling, company proxies.
[ -f "$HOME/.zshrc.local" ] && . "$HOME/.zshrc.local"
