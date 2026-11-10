<#
.SYNOPSIS
  Set up a Windows machine from this repo — the counterpart of install.sh.

.DESCRIPTION
  Installs a few essentials with winget, then points the usual config
  locations at this repo with small stub files (include / source / dot-source
  lines) rather than symlinks, so it needs neither admin rights nor Developer
  Mode. Your existing PowerShell profile is appended to, never replaced.

  Safe to re-run. Any file it would replace is backed up to
  ~/.dotfiles-backup/<timestamp>/ first; files already up to date are left
  alone. If you move the repo, re-run this to repoint the stubs.

    git clone https://github.com/Sastopher/dotfiles.git
    pwsh -File dotfiles\windows\install.ps1

.PARAMETER NoWinget
  Skip installing the packages in windows/winget-packages.txt.

.PARAMETER DryRun
  Print what would happen, change nothing.
#>
#Requires -Version 7
[CmdletBinding()]
param(
  [switch]$NoWinget,
  [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

$Dotfiles = Split-Path $PSScriptRoot -Parent
$Repo     = $Dotfiles -replace '\\', '/'      # forward slashes for git / nvim / psmux
$Backup   = Join-Path $HOME ".dotfiles-backup\$(Get-Date -Format 'yyyyMMdd-HHmmss')"
$Marker   = 'Managed by dotfiles/windows/install.ps1'

function Bold($m) { Write-Host "==> $m" -ForegroundColor White }
function Info($m) { Write-Host "  → $m" -ForegroundColor Blue }
function Ok($m)   { Write-Host "  ✓ $m" -ForegroundColor Green }
function Warn($m) { Write-Host "  ! $m" -ForegroundColor Yellow }
function Dry($m)  { Write-Host "  [dry-run] $m" -ForegroundColor DarkGray }

function Backup-File([string]$Path) {
  $rel  = [IO.Path]::GetRelativePath($HOME, $Path)
  if ($rel.StartsWith('..')) { $rel = Split-Path $Path -Leaf }
  $dest = Join-Path $Backup $rel
  if ($DryRun) { Dry "back up $Path → $dest"; return }
  New-Item -ItemType Directory -Force (Split-Path $dest) | Out-Null
  Copy-Item $Path $dest -Force
  Info "backed up existing $(Split-Path $Path -Leaf) → $dest"
}

# Write-Stub <path> <content>: write a stub file, backing up anything different.
function Write-Stub([string]$Path, [string]$Content) {
  $name = Split-Path $Path -Leaf
  if (Test-Path $Path) {
    if ((Get-Content $Path -Raw) -eq $Content) { Ok "$name already set up"; return }
    Backup-File $Path
  }
  if ($DryRun) { Dry "write $Path"; return }
  New-Item -ItemType Directory -Force (Split-Path $Path) | Out-Null
  [IO.File]::WriteAllText($Path, $Content)   # UTF-8, no BOM
  Ok "wrote $Path"
}

# ── 1. winget packages ──────────────────────────────────────────────────────
if ($NoWinget) {
  Bold 'Packages (skipped)'
} elseif (-not (Get-Command winget -ErrorAction Ignore)) {
  Bold 'Packages'
  Warn 'winget not found — install "App Installer" from the Microsoft Store, then re-run'
} else {
  Bold 'Packages (windows/winget-packages.txt)'
  $ids = Get-Content (Join-Path $PSScriptRoot 'winget-packages.txt') |
    ForEach-Object { ($_ -replace '#.*$', '').Trim() } | Where-Object { $_ }
  foreach ($id in $ids) {
    winget list --id $id --exact --source winget --accept-source-agreements *> $null
    if ($LASTEXITCODE -eq 0) { Ok "$id"; continue }
    if ($DryRun) { Dry "winget install $id"; continue }
    Info "installing $id"
    winget install --id $id --exact --source winget --silent `
      --accept-package-agreements --accept-source-agreements
    if ($LASTEXITCODE -eq 0) { Ok "installed $id" } else { Warn "$id failed (exit $LASTEXITCODE) — try it by hand" }
  }
  # Pick up anything just installed without restarting the shell.
  $env:PATH = [Environment]::GetEnvironmentVariable('PATH', 'Machine') + ';' +
              [Environment]::GetEnvironmentVariable('PATH', 'User')
}

# ── 2. Git ──────────────────────────────────────────────────────────────────
Bold 'Git'
$gitconfig = Join-Path $HOME '.gitconfig'
$gitLocal  = Join-Path $HOME '.gitconfig.local'

# Identity goes in ~/.gitconfig.local, as on the mac. Carry it over from an
# existing ~/.gitconfig rather than asking again.
if (Test-Path $gitLocal) {
  Ok "~/.gitconfig.local exists ($(git config -f $gitLocal user.email))"
} else {
  $name  = if (Test-Path $gitconfig) { git config -f $gitconfig user.name }  else { $null }
  $email = if (Test-Path $gitconfig) { git config -f $gitconfig user.email } else { $null }
  if ($DryRun) {
    if ($email) { Dry "write ~/.gitconfig.local with $name <$email> from ~/.gitconfig" }
    else        { Dry 'prompt for git name/email' }
  } else {
    if (-not $name)  { $name  = Read-Host '  git user.name ' }
    if (-not $email) { $email = Read-Host '  git user.email' }
    [IO.File]::WriteAllText($gitLocal, @"
# Machine-local git identity. Not tracked in the dotfiles repo.
[user]
	name = $name
	email = $email
"@ + "`n")
    Ok "wrote ~/.gitconfig.local ($email)"
  }
}

Write-Stub $gitconfig @"
# $Marker — edit the repo, not this file.
# Machine-local settings go in ~/.gitconfig.local, which is read last.
[include]
	path = $Repo/home/.gitconfig
	path = $Repo/windows/gitconfig
[core]
	excludesFile = $Repo/config/git/ignore
[include]
	path = ~/.gitconfig.local

"@

# ── 3. Neovim ───────────────────────────────────────────────────────────────
Bold 'Neovim'
Write-Stub (Join-Path $env:LOCALAPPDATA 'nvim\init.lua') @"
-- $Marker — edit the repo, not this file.
-- There's no ~/.vimrc on Windows, so source the repo's before the shared init.lua.
local repo = "$Repo"
vim.cmd.source(vim.fn.fnameescape(repo .. "/home/.vimrc"))
dofile(repo .. "/config/nvim/init.lua")

"@

# ── 4. psmux ────────────────────────────────────────────────────────────────
Bold 'psmux'
Write-Stub (Join-Path $HOME '.psmux.conf') @"
# $Marker — edit the repo, not this file.
source-file "$Repo/windows/psmux.conf"

"@
$tmuxConf = Join-Path $HOME '.tmux.conf'
if (Test-Path $tmuxConf) {
  Info '~/.tmux.conf left in place; psmux now reads ~/.psmux.conf instead'
}

# ── 5. PowerShell profile ───────────────────────────────────────────────────
Bold 'PowerShell profile'
$profilePath = $PROFILE.CurrentUserCurrentHost
$repoProfile = Join-Path $Dotfiles 'windows\profile.ps1'
$line = ". '$repoProfile'  # $Marker"
$existing = if (Test-Path $profilePath) { Get-Content $profilePath } else { @() }
$current = $existing | Where-Object { $_ -like "*$Marker*" }
if ($current -and ($current -eq $line)) {
  Ok "$profilePath already dot-sources the repo profile"
} elseif ($DryRun) {
  Dry "append to $profilePath`: $line"
} else {
  if (Test-Path $profilePath) { Backup-File $profilePath }
  New-Item -ItemType Directory -Force (Split-Path $profilePath) | Out-Null
  $kept = @($existing | Where-Object { $_ -notlike "*$Marker*" })
  Set-Content $profilePath ($kept + $line) -Encoding utf8NoBOM
  Ok "added the repo profile to $profilePath"
}

# ── 6. Windows Terminal ─────────────────────────────────────────────────────
# A fragment adds a scheme + profile alongside settings.json, never editing it.
Bold 'Windows Terminal'
$fragmentDir = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows Terminal\Fragments\dotfiles'
$fragmentSrc = Join-Path $PSScriptRoot 'terminal-fragment.json'
Write-Stub (Join-Path $fragmentDir 'dotfiles.json') (Get-Content $fragmentSrc -Raw)

# ── Done ────────────────────────────────────────────────────────────────────
Bold 'Done'
if (Test-Path $Backup) { Info "replaced files backed up to $Backup" }
Write-Host @'

  Remaining manual steps:
    1. gh auth login            (if not already; git uses gh for GitHub credentials)
    2. Windows Terminal → Settings → Startup → Default profile → "tmux"
       if you want every new tab inside tmux, like Ghostty on the mac.
    3. Open a new terminal (or: . $PROFILE)

'@
