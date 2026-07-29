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
  # Computed before the elevated branch below, because the root prompt shows
  # the same directory and git segment the normal one does.
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

  if ($script:IsElevated) {
    # The root prompt is the *standard* ANSI range, not the bright one the
    # normal prompt uses, so these are the Dark* names: \e[0;31m / %F{1} ->
    # DarkRed, \e[0;37m / %F{7} -> Gray, \e[0;90m / %F{8} -> DarkGray. Plain
    # `Red` here would be bright red (\e[0;91m), a shade too light — the same
    # mismatch called out in CLAUDE.md's colour-mapping note.
    Write-Host "$script:UserName " -NoNewline -ForegroundColor DarkRed
    Write-Host $Path -NoNewline -ForegroundColor Gray
    if ($Branch) { Write-Host " ($Branch)" -NoNewline -ForegroundColor DarkGray }
    Write-Host " #" -NoNewline -ForegroundColor DarkRed
    return " "
  }

  Write-Host "λ " -NoNewline -ForegroundColor Cyan
  Write-Host "$script:UserName" -NoNewline -ForegroundColor Red
  Write-Host ": " -NoNewline -ForegroundColor Cyan
  Write-Host $Path -NoNewline -ForegroundColor Yellow
  if ($Branch) { Write-Host " ($Branch)" -NoNewline -ForegroundColor Blue }
  Write-Host " ∫" -NoNewline -ForegroundColor Green
  " "
}
