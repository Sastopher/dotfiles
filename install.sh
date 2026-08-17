#!/usr/bin/env bash
#
# Bootstrap a new macOS machine from this repo.
#
#   git clone git@github.com:Sastopher/dotfiles.git ~/Dev/dotfiles
#   ~/Dev/dotfiles/install.sh
#
# Safe to re-run. Existing real files are backed up to ~/.dotfiles-backup/<ts>/
# before being replaced with symlinks; correct symlinks are left alone.
#
# Flags:
#   --no-brew    skip Homebrew install + brew bundle
#   --no-macos   skip the macOS defaults in macos.sh
#   --dry-run    print what would happen, change nothing

set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"
DO_BREW=1 DO_MACOS=1 DRY_RUN=0

for arg in "$@"; do
  case "$arg" in
    --no-brew)  DO_BREW=0 ;;
    --no-macos) DO_MACOS=0 ;;
    --dry-run)  DRY_RUN=1 ;;
    -h|--help)  sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown flag: $arg" >&2; exit 1 ;;
  esac
done

bold() { printf '\033[1m%s\033[0m\n' "$*"; }
info() { printf '  \033[34m→\033[0m %s\n' "$*"; }
ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$*"; }
run()  { if [ "$DRY_RUN" = 1 ]; then printf '  \033[90m[dry-run] %s\033[0m\n' "$*"; else "$@"; fi; }

# link <source-in-repo> <target-in-home>
link() {
  local src="$1" dst="$2"
  if [ ! -e "$src" ]; then warn "missing in repo, skipping: $src"; return; fi
  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then ok "$(basename "$dst") already linked"; return; fi
  run mkdir -p "$(dirname "$dst")"
  if [ -e "$dst" ] || [ -L "$dst" ]; then
    run mkdir -p "$BACKUP/$(dirname "${dst#$HOME/}")"
    run mv "$dst" "$BACKUP/${dst#$HOME/}"
    info "backed up existing $(basename "$dst")"
  fi
  run ln -s "$src" "$dst"
  ok "linked $(basename "$dst")"
}

# ── 1. Xcode command line tools ─────────────────────────────────────────────
bold "==> Command line tools"
if xcode-select -p >/dev/null 2>&1; then
  ok "already installed"
else
  info "triggering install — finish the GUI prompt, then re-run this script"
  run xcode-select --install
  exit 0
fi

# ── 2. Homebrew + packages ──────────────────────────────────────────────────
if [ "$DO_BREW" = 1 ]; then
  bold "==> Homebrew"
  if command -v brew >/dev/null 2>&1; then
    ok "already installed"
  else
    info "installing Homebrew"
    run /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi
  if [ -x /opt/homebrew/bin/brew ]; then eval "$(/opt/homebrew/bin/brew shellenv)"; fi

  bold "==> Packages (Brewfile)"
  info "this takes a while on a fresh machine"
  run brew bundle --file="$DOTFILES/Brewfile"
else
  bold "==> Homebrew (skipped)"
fi

# ── 3. Symlink dotfiles ─────────────────────────────────────────────────────
bold "==> Dotfiles"
for f in "$DOTFILES"/home/.*; do
  base="$(basename "$f")"
  case "$base" in .|..) continue ;; esac
  link "$f" "$HOME/$base"
done

link "$DOTFILES/config/ghostty/config" "$HOME/.config/ghostty/config"
link "$DOTFILES/config/git/ignore"     "$HOME/.config/git/ignore"
link "$DOTFILES/config/nvim/init.lua"  "$HOME/.config/nvim/init.lua"
link "$DOTFILES/config/starship.toml"  "$HOME/.config/starship.toml"

# ── 4. Git identity ─────────────────────────────────────────────────────────
bold "==> Git identity"
if [ -f "$HOME/.gitconfig.local" ]; then
  ok "~/.gitconfig.local exists ($(git config -f "$HOME/.gitconfig.local" user.email 2>/dev/null || echo 'no email set'))"
elif [ "$DRY_RUN" = 1 ]; then
  info "[dry-run] would prompt for git name/email"
else
  read -r -p "  git user.name:  " GIT_NAME
  read -r -p "  git user.email: " GIT_EMAIL
  cat > "$HOME/.gitconfig.local" <<EOF
# Machine-local git identity. Not tracked in the dotfiles repo.
[user]
	name = $GIT_NAME
	email = $GIT_EMAIL
EOF
  ok "wrote ~/.gitconfig.local"
fi

# ── 5. Claude Code settings ─────────────────────────────────────────────────
# Copied, not symlinked: Claude Code rewrites this file in place, which would
# otherwise push local UI state into the repo on every toggle.
bold "==> Claude Code"
if [ -f "$HOME/.claude/settings.json" ]; then
  ok "settings.json exists, leaving it alone (repo copy: claude/settings.json)"
else
  run mkdir -p "$HOME/.claude"
  run cp "$DOTFILES/claude/settings.json" "$HOME/.claude/settings.json"
  ok "installed settings.json"
fi

# ── 6. SSH config ───────────────────────────────────────────────────────────
# Also copied — you will add work-specific hosts to it that should not be public.
bold "==> SSH"
if [ -f "$HOME/.ssh/config" ]; then
  ok "config exists, leaving it alone"
else
  run mkdir -p "$HOME/.ssh"
  run chmod 700 "$HOME/.ssh"
  run cp "$DOTFILES/ssh/config" "$HOME/.ssh/config"
  run chmod 600 "$HOME/.ssh/config"
  ok "installed ssh config"
fi
if [ ! -f "$HOME/.ssh/id_ed25519" ]; then
  warn "no SSH key found — generate one and add it to GitHub:"
  warn "    ssh-keygen -t ed25519 -C \"your@email\" && gh auth login"
fi

# ── 7. tmux plugins ─────────────────────────────────────────────────────────
bold "==> tmux plugins"
TPM_INSTALL=/opt/homebrew/opt/tpm/share/tpm/bin/install_plugins
if [ -x "$TPM_INSTALL" ]; then
  run mkdir -p "$HOME/.tmux/plugins"
  run "$TPM_INSTALL"
  ok "tpm plugins installed"
else
  warn "tpm not found — run 'brew install tpm', then prefix + I inside tmux"
fi

# ── 8. asdf runtimes ────────────────────────────────────────────────────────
bold "==> asdf runtimes"
# No global ~/.tool-versions ships with this repo — runtimes are chosen
# per-project. If you have created one, its plugins are installed here.
if ! command -v asdf >/dev/null 2>&1; then
  warn "asdf not installed, skipping runtimes"
elif [ ! -f "$HOME/.tool-versions" ]; then
  ok "no ~/.tool-versions — set versions per-project with 'asdf local <tool> <version>'"
else
  while read -r plugin _; do
    case "$plugin" in ''|\#*) continue ;; esac
    if asdf plugin list 2>/dev/null | grep -qx "$plugin"; then
      ok "plugin $plugin present"
    else
      run asdf plugin add "$plugin"
      ok "added plugin $plugin"
    fi
  done < "$HOME/.tool-versions"
  info "installing versions from ~/.tool-versions"
  run asdf install || warn "some runtimes failed to build — install them individually"
fi

# ── 9. macOS defaults ───────────────────────────────────────────────────────
if [ "$DO_MACOS" = 1 ]; then
  bold "==> macOS defaults"
  run bash "$DOTFILES/macos.sh"
else
  bold "==> macOS defaults (skipped)"
fi

# ── Done ────────────────────────────────────────────────────────────────────
bold "==> Done"
if [ -d "$BACKUP" ]; then info "replaced files backed up to $BACKUP"; fi
cat <<'EOF'

  Remaining manual steps:
    1. Open Ghostty once and grant it Accessibility/Full Disk Access if prompted.
    2. gh auth login
    3. Karabiner-Elements: launch it, grant Input Monitoring, then
       cp extras/karabiner/karabiner.json ~/.config/karabiner/karabiner.json
    4. 1Password: sign in, then Settings > Developer > Integrate with 1Password CLI
       (and "Use the SSH agent" if you want the IdentityAgent line in ~/.ssh/config)
    5. gt auth --token <token>   # https://app.graphite.dev/settings/cli
    6. Restart your terminal (or: exec zsh)

EOF
