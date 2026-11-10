# dotfiles

macOS developer setup — Ghostty + tmux + vim/neovim + zsh, Catppuccin Mocha throughout.
A smaller Windows layer lives in `windows/` — see [Windows](#windows).

## Bootstrap a new machine

```sh
xcode-select --install                                    # if not already present
git clone https://github.com/Sastopher/dotfiles.git ~/Dev/dotfiles
~/Dev/dotfiles/install.sh
```

Then restart the terminal. `install.sh --dry-run` shows what it would do without
touching anything.

| Flag | Effect |
| --- | --- |
| `--dry-run` | print actions, change nothing |
| `--no-brew` | skip Homebrew + `brew bundle` |
| `--no-macos` | skip `macos.sh` |

Re-running is safe: correct symlinks are left alone, and any real file it would
replace is moved to `~/.dotfiles-backup/<timestamp>/` first.

## What's in here

```
Brewfile                      packages & casks (dev essentials only)
install.sh                    bootstrap; symlinks everything below
macos.sh                      keyboard repeat rate, Finder, Dock, screenshots
home/                         → symlinked into ~
  .zshrc .zshenv .zprofile    shell; starship prompt, asdf, aliases
  .tmux.conf                  prefix M-a, tpm plugins, Catppuccin status bar
  .vimrc                      minimal vim
  .gitconfig                  aliases & settings (identity is NOT here)
config/                       → symlinked into ~/.config
  ghostty/config              theme, font, macos-option-as-alt, tmux autostart
  nvim/init.lua               sources ~/.vimrc + neovim-only settings
  starship.toml               prompt, Catppuccin Mocha
  git/ignore                  global gitignore
claude/settings.json          Claude Code settings (copied, not symlinked)
claude/hooks/tmux-state.sh    → symlinked; Claude state on tmux panes/windows (see .tmux.conf)
ssh/config                    minimal; copied only if ~/.ssh/config is absent
                              (1Password agent line included but commented)
extras/
  karabiner/                  caps→escape, fn↔ctrl (manual copy, see below)
windows/                      Windows only; install.sh never touches it
```

## Windows

A deliberately small subset: git (aliases, settings, gh as credential
helper), neovim, tmux via [psmux](https://github.com/psmux/psmux), the
starship prompt, and a PowerShell profile with the same aliases. Requires
PowerShell 7 and winget.

```powershell
git clone https://github.com/Sastopher/dotfiles.git
pwsh -File dotfiles\windows\install.ps1          # -DryRun to preview, -NoWinget to skip packages
```

It doesn't symlink (that needs admin or Developer Mode). Each config location
gets a tiny stub that includes or sources the repo file, so edits in the repo
apply immediately, and if the repo moves you just re-run the installer:

| Location | Stub points at |
| --- | --- |
| `~/.gitconfig` | `home/.gitconfig`, then `windows/gitconfig` (gh helper, nvim editor), then `~/.gitconfig.local` |
| `%LOCALAPPDATA%\nvim\init.lua` | `home/.vimrc` + `config/nvim/init.lua` |
| `~/.psmux.conf` | `windows/psmux.conf` |
| `$PROFILE` | one appended line dot-sourcing `windows/profile.ps1`; the rest of your profile is kept |
| Windows Terminal fragment | adds a *Catppuccin Mocha* scheme and a *tmux* profile (runs psmux's `tmux.exe`); `settings.json` is not edited |

Anything replaced is backed up to `~/.dotfiles-backup/<timestamp>/`, the same
as on the mac. An existing git identity in `~/.gitconfig` is moved into
`~/.gitconfig.local`. Machine-local PowerShell goes in `~/.profile.local.ps1`.

```
windows/
  install.ps1                 bootstrap (the install.sh counterpart)
  winget-packages.txt         packages (the Brewfile counterpart)
  gitconfig                   Windows-only git overrides
  psmux.conf                  port of home/.tmux.conf
  profile.ps1                 PowerShell aliases, EDITOR, starship, tmux pane titles
  terminal-fragment.json      Windows Terminal scheme + profile
```

`windows/psmux.conf` is a copy of `.tmux.conf`, not an include of it, so
**changes to keybindings or the status bar have to be made in both files.** The
port leaves out the parts that can't work on Windows: the Ghostty
terminal-features, tpm (the pain-control bindings are written out inline), the
`pbcopy` yank (psmux copies to the Windows clipboard on its own), and the
Claude Code pane-state hooks, which are bash. Claude Code's `settings.json`
isn't installed on Windows for the same reason (its hooks call `afplay` and
those scripts).

To start every terminal tab in tmux, as Ghostty does, pick *tmux* as the
default profile in Windows Terminal → Settings → Startup.

## The terminal stack

The pieces are interdependent — changing one usually means changing another:

- **Ghostty** sets `macos-option-as-alt = left`, which is what makes tmux's `M-a`
  prefix reachable. Without it Option+a types `å`.
- Ghostty launches straight into tmux via
  `command = /bin/zsh -lc "tmux new -A -s main"`. Comment that line out if you
  want a bare shell.
- Ghostty speaks the kitty keyboard protocol, and `.tmux.conf` sets
  `extended-keys on` + `terminal-features "xterm-ghostty:RGB:extkeys"`. Together
  those make Shift+Enter distinguishable from Enter inside tmux, which is what
  lets Claude Code insert a newline instead of submitting.
- The font must be a Nerd Font (`font-jetbrains-mono-nerd-font` in the Brewfile)
  or the tmux status bar and starship prompt render as tofu boxes.

tmux plugins are managed by **tpm installed from Homebrew**, not the usual
`git clone` into `~/.tmux/plugins/tpm` — `.tmux.conf` sources it from
`/opt/homebrew/opt/tpm/share/tpm/tpm`. `install.sh` runs tpm's `install_plugins`
for you; inside tmux, `prefix + I` still works normally.

## 1Password and Graphite

Both ship in the `Brewfile`; both need a one-time auth step the installer can't
do for you.

- **1Password** — `1password` (desktop) + `1password-cli` (`op`). Sign in to the
  desktop app first, then turn on *Settings → Developer → Integrate with 1Password
  CLI* so `op` unlocks with Touch ID instead of prompting for the account
  password. To use it as your SSH agent, enable *Settings → Developer → Use the
  SSH agent* and uncomment the `IdentityAgent` line in `ssh/config` — in that
  order, since ssh errors on every host if the socket isn't there yet.
- **Graphite** — `gt`, installed from `withgraphite/tap` (it is not in
  homebrew-core). Run `gt auth --token <token>` from
  <https://app.graphite.dev/settings/cli>, then `gt init` inside each repo.
  Shell completion is cached to `~/.cache/gt-completion.zsh` by `.zshrc`; delete
  that file after a `gt` upgrade to pick up new commands.

## Manual steps after install

1. `gh auth login`
2. Generate an SSH key if this is a fresh machine:
   `ssh-keygen -t ed25519 -C "you@example.com"`, then add it to GitHub.
3. **Karabiner** — launch it once and grant Input Monitoring, *then*
   `cp extras/karabiner/karabiner.json ~/.config/karabiner/karabiner.json`.
   Copying before first launch gets the file overwritten. This maps
   caps lock → escape, escape → caps lock, and swaps fn ↔ left control.
4. Grant Ghostty Accessibility / Full Disk Access if macOS prompts.
5. Sign in to 1Password and run `gt auth` — see the section above.
6. Install anything from the "manual installs" list at the bottom of the
   `Brewfile` (Chrome, Docker, Claude Code).

## Machine-local, never committed

Two files are read if present and are deliberately kept out of git:

- `~/.gitconfig.local` — `user.name` / `user.email`. `install.sh` prompts for
  these on first run. This is why the tracked `.gitconfig` has no identity in
  it: the same repo can back a personal and a work machine without leaking a
  personal address into work commits.
- `~/.zshrc.local` — work env vars, tokens, internal tooling, proxies.

Nothing in this repo contains keys, tokens, or credentials.

## Deviations from the old machine

Worth knowing, since these are not a 1:1 restore:

- **Brewfile is trimmed.** Dropped: calibre, gimp, obsidian, brave-browser,
  iterm2, ffmpeg(+full), poppler, ollama, taskwarrior, timewarrior, the
  old-employer tooling (azure-cli, cloudflared, flyctl), and the language
  runtimes (elixir, python@3.12, postgresql@14) — install those per-project via
  `asdf` or `brew` once you know what the new job actually uses. `tmux` and
  `git` were transitive dependencies before and are now pinned explicitly.
  Added: `fd`, `tree`, `direnv`, `graphite`, `1password` + `1password-cli`.
- **No `~/.tool-versions` is shipped.** asdf is installed but unpinned, so a new
  machine starts with no global runtime versions. Set them per-project with
  `asdf local <tool> <version>`.
- **`~/.config/nvim/init.lua` is new.** `vim` was aliased to `nvim`, but nvim
  never read `~/.vimrc`, so the alias silently gave you an unconfigured editor.
  It now sources the vimrc and adds neovim-only settings.
- **`~/.config/starship.toml` is new.** starship previously ran on stock
  defaults; this themes it to match Ghostty and tmux. Delete it to go back.
- **`.zshrc` tmux autostart is fixed.** The old condition was
  `[[ -n "\$PS1" ]] && [[ -z "\$TMUX" ]]` — the backslashes made zsh compare the
  literal strings `$PS1` and `$TMUX`, so `-z` was never true and the block never
  ran. It now uses `[[ -o interactive ]]` and a real `$TMUX` test, so SSH
  sessions actually auto-attach.
- **`.gitconfig` gained** `pull.rebase`, `fetch.prune`, `rerere.enabled`,
  `branch.sort`, and `column.ui`, and lost the hardcoded identity.
