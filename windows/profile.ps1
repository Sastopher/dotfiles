# PowerShell profile — the Windows counterpart of home/.zshrc.
# Dot-sourced from $PROFILE by a single line that windows/install.ps1 appends;
# whatever else is in $PROFILE keeps working.

$DotfilesRoot = Split-Path $PSScriptRoot -Parent

# ── Aliases ─────────────────────────────────────────────────────────────────
if (Get-Command nvim -ErrorAction Ignore) {
  Set-Alias vim nvim
  Set-Alias vi  nvim
  $env:EDITOR = 'nvim'
}
Set-Alias g git
function ll { Get-ChildItem @args }
function la { Get-ChildItem -Force @args }

# ── PATH ────────────────────────────────────────────────────────────────────
$localBin = Join-Path $HOME '.local\bin'
if ((Test-Path $localBin) -and ($env:PATH -notlike "*$localBin*")) {
  $env:PATH = "$localBin;$env:PATH"
}

# ── Prompt ──────────────────────────────────────────────────────────────────
# Same config as the mac. Needs a Nerd Font in the terminal (the "psmux"
# Windows Terminal profile uses one), or the powerline glyphs show as boxes.
if (Get-Command starship -ErrorAction Ignore) {
  $env:STARSHIP_CONFIG = Join-Path $DotfilesRoot 'config\starship.toml'
  Invoke-Expression (& starship init powershell)
}

# ── tmux pane title ─────────────────────────────────────────────────────────
# psmux border labels only expand a few variables (#{pane_title} yes,
# #{pane_current_path} no), and psmux ignores OSC 2 / console-title changes,
# so name the pane with `tmux select-pane -T` whenever the folder changes and
# let pane-border-format show #{pane_title}. ~25 ms, only on a cd.
if ($env:TMUX_PANE -and (Get-Command tmux -ErrorAction Ignore)) {
  $script:lastPaneTitle = $null
  function Set-PaneTitle {
    $leaf = Split-Path -Leaf $PWD.ProviderPath
    if (-not $leaf) { $leaf = $PWD.ProviderPath }
    if ($leaf -ne $script:lastPaneTitle) {
      $script:lastPaneTitle = $leaf
      tmux select-pane -t $env:TMUX_PANE -T $leaf 2>$null
    }
  }
  if (Get-Command starship -ErrorAction Ignore) {
    function Invoke-Starship-PreCommand { Set-PaneTitle }
  } else {
    $function:__dotfilesPrompt = $function:prompt
    function prompt { Set-PaneTitle; & $function:__dotfilesPrompt }
  }
}

# ── Machine-local overrides (never committed) ───────────────────────────────
$localProfile = Join-Path $HOME '.profile.local.ps1'
if (Test-Path $localProfile) { . $localProfile }
