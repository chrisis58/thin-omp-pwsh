# Thin Posh Theme -- one-line installer
# Usage: iwr https://raw.githubusercontent.com/chrisis58/thin-omp-pwsh/main/install.ps1 | iex

param(
    [string]$Branch = "main",
    [string]$Repo = "https://raw.githubusercontent.com/chrisis58/thin-omp-pwsh",
    [switch]$Force
)

$ErrorActionPreference = "Stop"

Write-Host "Installing Thin Posh Theme..." -ForegroundColor Cyan

# 1. Check oh-my-posh
if (-not (Get-Command oh-my-posh -ErrorAction Ignore)) {
    Write-Host "oh-my-posh not found. Install it first:" -ForegroundColor Red
    Write-Host "  winget install JanDeDobbeleer.OhMyPosh -s winget" -ForegroundColor Red
    return
}

$version = [int]((oh-my-posh --version 2>$null) -split '\.')[0]
if ($version -lt 19) {
    Write-Host "oh-my-posh version too old ($version), please upgrade to v19+:" -ForegroundColor Red
    Write-Host "  winget upgrade JanDeDobbeleer.OhMyPosh" -ForegroundColor Red
    return
}

# 2. Download thin.omp.json
$themeDir = Join-Path $HOME "Documents\PowerShell\posh-themes"
$themeFile = Join-Path $themeDir "thin.omp.json"
New-Item -ItemType Directory -Force $themeDir | Out-Null
$themeUrl = "$Repo/$Branch/thin.omp.json"
Write-Host "Downloading $themeUrl ..." -ForegroundColor Gray
Invoke-WebRequest -Uri $themeUrl -OutFile $themeFile
Write-Host "  -> $themeFile" -ForegroundColor Green

# 3. Handle profile
$profileUrl = "$Repo/$Branch/profile.ps1"
$profileContent = Invoke-WebRequest -Uri $profileUrl -UseBasicParsing | Select-Object -ExpandProperty Content
$userProfile = $PROFILE.CurrentUserAllHosts

$existing = if (Test-Path $userProfile) { Get-Content $userProfile -Raw } else { "" }

# Detect existing oh-my-posh config
$hasOldOmp = $existing -match 'oh-my-posh\s+init\s+(pwsh|powershell)'
$hasOmpCache = $existing -match '\$ompCacheDir|\.omp-cache'
$hasOmpStreaming = $existing -match 'Enable-PoshStreaming'
$hasOmpKeyHandler = $existing -match 'Enable-KeyHandlers'
$hasThinTheme = $existing -match '# =+.*oh-my-posh.*=+' -or $existing -match 'thin\.omp\.json'

if ($hasThinTheme) {
    Write-Host "thin-omp-pwsh already installed, skipping profile." -ForegroundColor Yellow
} elseif ($hasOldOmp -or $hasOmpCache -or $hasOmpStreaming -or $hasOmpKeyHandler) {
    Write-Host "Existing oh-my-posh config detected:" -ForegroundColor Yellow
    if ($hasOldOmp)       { Write-Host "  - oh-my-posh init" }
    if ($hasOmpCache)     { Write-Host "  - cache config" }
    if ($hasOmpStreaming) { Write-Host "  - Enable-PoshStreaming" }
    if ($hasOmpKeyHandler){ Write-Host "  - Enable-KeyHandlers" }

    $lines = $existing -split "`r?`n"
    $toRemove = $lines | Where-Object {
        $_ -match 'oh-my-posh\s+init\s+(pwsh|powershell)' -or
        $_ -match '\$ompCacheDir|\$ompInitCache|\.omp-cache' -or
        $_ -match '\$ompConfig.*omp\.json' -or
        $_ -match 'Enable-PoshStreaming' -or
        $_ -match 'Enable-KeyHandlers' -or
        $_ -match '# =+.*oh-my-posh.*=+' -or
        $_ -match 'posh-themes'
    }

    Write-Host ""
    Write-Host "Lines to be removed:" -ForegroundColor Red
    $toRemove | ForEach-Object { Write-Host "  - $_" -ForegroundColor DarkGray }

    $confirmed = $Force
    if (-not $confirmed) {
        $response = Read-Host "`nConfirm replacement? [y/N]"
        $confirmed = $response -match '^[yY]'
    }

    if ($confirmed) {
        $backup = "$userProfile.bak-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        Copy-Item $userProfile $backup
        Write-Host "Backed up profile -> $backup" -ForegroundColor Gray

        $cleaned = $lines | Where-Object {
            $_ -notmatch 'oh-my-posh\s+init\s+(pwsh|powershell)' -and
            $_ -notmatch '\$ompCacheDir|\$ompInitCache|\.omp-cache' -and
            $_ -notmatch '\$ompConfig.*omp\.json' -and
            $_ -notmatch 'Enable-PoshStreaming' -and
            $_ -notmatch 'Enable-KeyHandlers' -and
            $_ -notmatch '# =+.*oh-my-posh.*=+' -and
            $_ -notmatch 'posh-themes'
        }
        $existing = ($cleaned -join "`n").TrimEnd()
        Set-Content -Path $userProfile -Value "$existing`n`n$profileContent"
        Write-Host "Replaced with thin-omp-pwsh." -ForegroundColor Green
    } else {
        Write-Host "Cancelled, profile unchanged." -ForegroundColor Yellow
    }
} else {
    if ($existing) {
        Add-Content -Path $userProfile -Value "`n$profileContent"
    } else {
        New-Item -ItemType File -Force $userProfile | Out-Null
        Set-Content -Path $userProfile -Value $profileContent
    }
    Write-Host "  -> Written to $userProfile" -ForegroundColor Green
}

Write-Host ""
Write-Host "Done! Restart PowerShell or run:" -ForegroundColor Cyan
Write-Host "  . `$PROFILE.CurrentUserAllHosts" -ForegroundColor White
