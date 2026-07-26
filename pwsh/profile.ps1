$Host.UI.RawUI.WindowTitle = "PowerShell"

# Windows PowerShell 5.1 has no $IsWindows/$IsLinux/$IsMacOS; it is always Windows.
$script:OnWindows = $IsWindows -or $PSVersionTable.PSVersion.Major -le 5

$script:IsElevated = $false
if ($script:OnWindows) {
  try {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    $script:IsElevated = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
  } catch {}
} else {
  $script:IsElevated = ((id -u) -eq '0')
}

# $env:USERNAME/$env:USERPROFILE are Windows-only; pwsh on macOS/Linux needs the POSIX equivalents.
$script:UserName = if ($script:OnWindows) { $env:USERNAME } else { $env:USER }

function prompt {
  if ($script:IsElevated) {
    Write-Host "$script:UserName " -NoNewline -ForegroundColor Red
    Write-Host "$PWD " -NoNewline -ForegroundColor DarkGray
    Write-Host "#" -NoNewline -ForegroundColor Red
    return " "
  }

  try {
    $Branch = git rev-parse --abbrev-ref HEAD 2>$null
    if ($Branch -eq "HEAD") { $Branch = git rev-parse --short HEAD 2>$null }
  } catch {}

  $Path = $(
    if ($HOME -ne $PWD.Path) {
      # Split-Path -Leaf, not (Get-Item $PWD).BaseName: BaseName strips what
      # .NET considers the "extension", which for a dotfile-style directory
      # like ".dotfiles" is the entire name (the only "." is at position 0),
      # leaving an empty string. Split-Path -Leaf just returns the literal
      # last path segment, matching bash's \W / zsh's %1~.
      Split-Path -Path $PWD.Path -Leaf
    } else { "~" }
  )

  Write-Host "λ " -NoNewline -ForegroundColor Cyan
  Write-Host "$script:UserName" -NoNewline -ForegroundColor Red
  Write-Host ": " -NoNewline -ForegroundColor Cyan
  Write-Host $Path -NoNewline -ForegroundColor Yellow
  if ($Branch) { Write-Host " ($Branch)" -NoNewline -ForegroundColor Blue }
  Write-Host " ∫" -NoNewline -ForegroundColor Green
  " "
}
