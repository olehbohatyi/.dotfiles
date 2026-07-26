#Requires -Version 5.1
<#
.SYNOPSIS
  Links pwsh/profile.ps1 into the current PowerShell edition's profile.

.DESCRIPTION
  Windows PowerShell 5.1 and PowerShell 7+ (pwsh) each resolve $PROFILE to a
  different path, and pwsh's path differs again between Windows and
  macOS/Linux. Run this script from whichever edition/host you want to
  configure; run it again from the other edition if you use both.

  Targets $PROFILE.CurrentUserAllHosts (not CurrentUserCurrentHost) so the
  prompt applies in the console, VS Code, and any other host, matching how
  bash/zsh apply to every interactive shell. This script never hardcodes
  that path itself - see .NOTES for why.

.PARAMETER Adopt
  If a real (non-symlink) profile already exists at the target path, copy
  its content into this repo's pwsh/profile.ps1 instead of backing it up.
  Review the result with 'git diff' before committing. See "Merging into an
  existing system" in README.md before using this.

.NOTES
  $PROFILE.CurrentUserAllHosts is always used instead of a literal path,
  per https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_profiles
  Its default value differs by edition/OS:
    - Windows PowerShell 5.1        $HOME\Documents\WindowsPowerShell\Profile.ps1
    - PowerShell 7+ on Windows      $HOME\Documents\PowerShell\Profile.ps1
    - PowerShell 7+ on Linux/macOS  ~/.config/powershell/profile.ps1
  Letting PowerShell resolve it also survives Documents-folder redirection
  or OneDrive Known Folder Move, which about_Profiles explicitly warns can
  silently move that path out from under a hardcoded guess.

  Creating a symlink on Windows needs Administrator rights or Developer Mode
  (SeCreateSymbolicLinkPrivilege) - see
  https://learn.microsoft.com/en-us/windows/apps/get-started/enable-your-device-for-development
  When that privilege is missing, this script falls back to copying the
  file, which works immediately but won't sync back to the repo.

  On Windows, the default (Restricted) execution policy blocks profile
  scripts from running at all - see the "Profiles and execution policy"
  section of about_Profiles linked above. This script warns if that's the
  case for the current user, since linking the file wouldn't otherwise
  visibly do anything.
#>
[CmdletBinding()]
param(
  [switch]$Adopt
)

$ErrorActionPreference = 'Stop'
$OnWindows = $IsWindows -or $PSVersionTable.PSVersion.Major -le 5

$RepoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$Source = Join-Path $RepoRoot 'pwsh/profile.ps1'
$Target = $PROFILE.CurrentUserAllHosts

if (-not (Test-Path -Path $Source)) {
  throw "Can't find $Source"
}

$TargetDir = Split-Path -Parent $Target
if (-not (Test-Path -Path $TargetDir)) {
  New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
}

$existing = Get-Item -Path $Target -ErrorAction SilentlyContinue
$existingIsSymlink = $existing -and ($existing.Attributes -band [IO.FileAttributes]::ReparsePoint)

if ($existingIsSymlink) {
  Remove-Item -Path $Target -Force
  $existing = $null
} elseif ($existing) {
  if ($Adopt) {
    Copy-Item -Path $Target -Destination $Source -Force
    Write-Host "Adopted existing profile content into $Source. Review with 'git diff' before committing." -ForegroundColor Yellow
  } else {
    $backupDir = Join-Path $HOME ".dotfiles-backup/$(Get-Date -Format yyyyMMdd-HHmmss)"
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    $backupPath = Join-Path $backupDir 'profile.ps1'
    Move-Item -Path $Target -Destination $backupPath
    Write-Host "Backed up existing profile to $backupPath" -ForegroundColor Yellow
  }
  Remove-Item -Path $Target -Force -ErrorAction SilentlyContinue
}

try {
  New-Item -ItemType SymbolicLink -Path $Target -Target $Source -Force | Out-Null
  Write-Host "Linked $Target -> $Source" -ForegroundColor Green
} catch {
  Copy-Item -Path $Source -Destination $Target -Force
  Write-Host "Copied $Source -> $Target (no admin rights/Developer Mode for a symlink; edits here won't sync back to the repo)." -ForegroundColor Yellow
  Write-Host "See the .NOTES in this script for how to enable symlinks." -ForegroundColor Yellow
}

if ($OnWindows -and (Get-ExecutionPolicy) -eq 'Restricted') {
  Write-Host
  Write-Host "Execution policy is Restricted, so this profile won't run on startup." -ForegroundColor Yellow
  Write-Host "Fix: Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned" -ForegroundColor Yellow
}
# Non-Windows pwsh has no equivalent restriction - about_Execution_Policies
# notes the policy is effectively Unrestricted there and can't be changed.

Write-Host "Restart PowerShell to pick up the new prompt."
