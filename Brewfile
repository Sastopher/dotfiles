# Dev essentials for a new work laptop.
#   brew bundle --file=~/Dev/dotfiles/Brewfile
#
# Deliberately NOT included (present on the old machine, reinstall by hand if
# you actually want them):
#   personal/media : calibre, gimp, obsidian, brave-browser, ffmpeg, ffmpeg-full,
#                    poppler, ollama, iterm2
#   old-employer   : azure-cli, cloudflared, flyctl
#   niche          : task (taskwarrior), timewarrior

tap "homebrew/bundle"

# ── Shell & prompt ──────────────────────────────────────────────────────────
brew "starship"          # prompt; config at ~/.config/starship.toml

# ── Terminal multiplexer ────────────────────────────────────────────────────
brew "tmux"              # was a transitive dep on the old machine, pinned here
brew "tpm"               # plugin manager; ~/.tmux.conf sources it from opt/tpm

# ── Editors ─────────────────────────────────────────────────────────────────
brew "neovim"            # `vim` is aliased to this
brew "vim"               # real vim, for when nvim is not wanted

# ── Core CLI ────────────────────────────────────────────────────────────────
brew "git"
brew "gh"                # GitHub CLI — run `gh auth login` after install
brew "ripgrep"
brew "fzf"
brew "bat"
brew "fd"                # fast find; pairs with fzf
brew "tree"
brew "direnv"            # per-project env vars; hooked in .zshrc

# ── Languages & runtimes ────────────────────────────────────────────────────
brew "asdf"              # versions pinned in ~/.tool-versions if configured

# ── Casks ───────────────────────────────────────────────────────────────────
cask "ghostty"                      # primary terminal
cask "font-jetbrains-mono-nerd-font" # required by ghostty config + tmux glyphs
cask "visual-studio-code"
cask "bruno"                        # API client
cask "karabiner-elements"           # see extras/karabiner
cask "rectangle"                    # window management
cask "flycut"                       # clipboard history
cask "slack"

# ── Manual installs (not in Homebrew / need SSO) ────────────────────────────
#   - Chrome              https://google.com/chrome
#   - Docker Desktop      (license check at a new company first)
#   - Claude Code         curl -fsSL https://claude.ai/install.sh | bash
#   - 1Password / Enpass  whatever the new company standardises on
