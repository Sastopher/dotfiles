#!/usr/bin/env bash
#
# Opinionated macOS defaults. Run standalone or via install.sh.
# Everything here is reversible; nothing touches user data.

set -euo pipefail

echo "  → applying macOS defaults"

# ── Keyboard ────────────────────────────────────────────────────────────────
# Fast key repeat — the single biggest quality-of-life change for vim users.
defaults write NSGlobalDomain KeyRepeat -int 2
defaults write NSGlobalDomain InitialKeyRepeat -int 15
# Disable press-and-hold accent menu so holding a key repeats instead.
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false
# Full keyboard access: Tab moves between all controls, not just text fields.
defaults write NSGlobalDomain AppleKeyboardUIMode -int 3

# ── Text input ──────────────────────────────────────────────────────────────
# Smart quotes and dashes corrupt code and commit messages.
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false

# ── Finder ──────────────────────────────────────────────────────────────────
defaults write com.apple.finder AppleShowAllFiles -bool true          # dotfiles
defaults write NSGlobalDomain AppleShowAllExtensions -bool true
defaults write com.apple.finder ShowPathbar -bool true
defaults write com.apple.finder ShowStatusBar -bool true
defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"   # search cwd
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false
defaults write com.apple.finder _FXSortFoldersFirst -bool true
# No .DS_Store on network or USB volumes.
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true

# ── Dock ────────────────────────────────────────────────────────────────────
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock autohide-delay -float 0
defaults write com.apple.dock autohide-time-modifier -float 0.15
defaults write com.apple.dock show-recents -bool false
defaults write com.apple.dock mru-spaces -bool false   # don't reorder spaces

# ── Screenshots ─────────────────────────────────────────────────────────────
mkdir -p "$HOME/Screenshots"
defaults write com.apple.screencapture location -string "$HOME/Screenshots"
defaults write com.apple.screencapture type -string "png"
defaults write com.apple.screencapture disable-shadow -bool true

# ── Misc ────────────────────────────────────────────────────────────────────
defaults write NSGlobalDomain NSWindowResizeTime -float 0.001   # faster windows
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
defaults write com.apple.LaunchServices LSQuarantine -bool false # no "are you sure"
defaults write com.apple.print.PrintingPrefs "Quit When Finished" -bool true

killall Finder Dock SystemUIServer 2>/dev/null || true

echo "  ✓ macOS defaults applied (some need a logout to take effect)"
