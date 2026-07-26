$Host.UI.RawUI.WindowTitle = "PowerShell"

function prompt {
  try {
    $Branch = git rev-parse --abbrev-ref HEAD
    if ($Branch -eq "HEAD") { $Branch = git rev-parse --short HEAD }
  } catch {}

  $Path = $(
    if ($env:USERPROFILE -ne $PWD) {
      (Get-Item -Path $PWD).BaseName
    } else { "~" }
  )

  Write-Host "λ " -NoNewline -ForegroundColor Cyan
  Write-Host "$env:USERNAME" -NoNewline -ForegroundColor Red
  Write-Host ": " -NoNewline -ForegroundColor Cyan
  Write-Host $Path -NoNewline -ForegroundColor Yellow
  if ($Branch) { Write-Host " ($Branch)" -NoNewline -ForegroundColor DarkGray }
  Write-Host " ∫" -NoNewline -ForegroundColor Green
  " "
}
