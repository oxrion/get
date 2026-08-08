# Oxrion dispatcher installer (Windows) — https://get.oxrion.com
#
#   irm https://get.oxrion.com/win | iex
#
# Installs ONLY the `oxrion` dispatcher into %LOCALAPPDATA%\Oxrion\bin and puts
# that folder on the user PATH. The dispatcher downloads the actual tools
# (recovery, licenser, …) on first use by reading get.oxrion.com/manifest.json.
# Idempotent: re-running reinstalls the latest dispatcher.

$ErrorActionPreference = 'Stop'

$Repo    = 'oxrion/dispatcher-releases'
$Base    = "https://github.com/$Repo/releases/latest/download"
$BinDir  = Join-Path $env:LOCALAPPDATA 'Oxrion\bin'
$Target  = Join-Path $BinDir 'oxrion.exe'

# --- detect architecture -> manifest artifact key ---------------------------
# Windows ships x64 only, matching the dispatcher build matrix.
$arch = $env:PROCESSOR_ARCHITECTURE
if ($arch -ne 'AMD64') {
  Write-Warning "Detected $arch. Only x64 Windows builds are published right now; installing the x64 build."
}
$asset = 'oxrion-windows-x64.exe'
$url   = "$Base/$asset"

Write-Host "Installing the Oxrion dispatcher ($asset)..."
New-Item -ItemType Directory -Force -Path $BinDir | Out-Null

# --- download to a temp file, then move into place --------------------------
$tmp = Join-Path $BinDir (".oxrion-" + [System.Guid]::NewGuid().ToString('N') + ".tmp")
try {
  Invoke-WebRequest -Uri $url -OutFile $tmp -UseBasicParsing
} catch {
  Remove-Item $tmp -Force -ErrorAction SilentlyContinue
  throw "Download failed: $url`n$($_.Exception.Message)"
}

if (-not (Test-Path $tmp) -or (Get-Item $tmp).Length -eq 0) {
  Remove-Item $tmp -Force -ErrorAction SilentlyContinue
  throw "Downloaded file is empty. The release may be missing $asset."
}

Move-Item -Force $tmp $Target
Write-Host "Installed: $Target"

# --- put the bin dir on the USER PATH (never machine PATH) ------------------
$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
if ([string]::IsNullOrEmpty($userPath)) { $userPath = '' }

$onPath = $userPath.Split(';') | Where-Object { $_.TrimEnd('\') -ieq $BinDir.TrimEnd('\') }
if (-not $onPath) {
  $newPath = if ($userPath.TrimEnd(';') -eq '') { $BinDir } else { $userPath.TrimEnd(';') + ';' + $BinDir }
  [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
  # Reflect it in the current session too, so `oxrion` works without reopening.
  $env:Path = $env:Path.TrimEnd(';') + ';' + $BinDir
  Write-Host "Added $BinDir to your user PATH."
  Write-Host "Open a new terminal for it to take effect everywhere."
} else {
  Write-Host "$BinDir is already on your PATH."
}

Write-Host ''
Write-Host 'Done. Try:  oxrion --help'
Write-Host "The first time you run a tool (e.g. 'oxrion recovery'), it downloads that tool automatically."
