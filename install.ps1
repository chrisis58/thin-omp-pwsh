# Thin Posh Theme — 一键安装脚本
# 用法: iwr https://raw.githubusercontent.com/chrisis58/thin-omp-pwsh/main/install.ps1 | iex

param(
    [string]$Branch = "main",
    [string]$Repo = "https://raw.githubusercontent.com/chrisis58/thin-omp-pwsh",
    [switch]$Force
)

$ErrorActionPreference = "Stop"

Write-Host "Thin Posh Theme 安装中..." -ForegroundColor Cyan

# 1. 检查 oh-my-posh
if (-not (Get-Command oh-my-posh -ErrorAction Ignore)) {
    Write-Host "请先安装 oh-my-posh: winget install JanDeDobbeleer.OhMyPosh -s winget" -ForegroundColor Red
    return
}

$version = (oh-my-posh --version 2>$null) -as [int]
if ($version -lt 19) {
    Write-Host "oh-my-posh 版本过低 ($version)，请升级到 v19+:" -ForegroundColor Red
    Write-Host "  winget upgrade JanDeDobbeleer.OhMyPosh" -ForegroundColor Red
    return
}

# 2. 下载 thin.omp.json
$themeDir = Join-Path $HOME "Documents\PowerShell\posh-themes"
$themeFile = Join-Path $themeDir "thin.omp.json"
New-Item -ItemType Directory -Force $themeDir | Out-Null
$themeUrl = "$Repo/$Branch/thin.omp.json"
Write-Host "下载 $themeUrl ..." -ForegroundColor Gray
Invoke-WebRequest -Uri $themeUrl -OutFile $themeFile
Write-Host "  -> $themeFile" -ForegroundColor Green

# 3. 处理 profile — 检查旧配置
$profileUrl = "$Repo/$Branch/profile.ps1"
$profileContent = Invoke-WebRequest -Uri $profileUrl -UseBasicParsing | Select-Object -ExpandProperty Content
$userProfile = $PROFILE.CurrentUserAllHosts

$existing = if (Test-Path $userProfile) { Get-Content $userProfile -Raw } else { "" }

# 检测已有的 oh-my-posh 相关配置
$hasOldOmp = $existing -match 'oh-my-posh\s+init\s+(pwsh|powershell)'
$hasOmpCache = $existing -match '\$ompCacheDir|\.omp-cache'
$hasOmpStreaming = $existing -match 'Enable-PoshStreaming'
$hasOmpKeyHandler = $existing -match 'Enable-KeyHandlers'
$hasThinTheme = $existing -match '# =+.*极速 oh-my-posh.*=+' -or $existing -match 'thin\.omp\.json'

if ($hasThinTheme) {
    Write-Host "检测到已安装 thin-omp-pwsh，跳过 profile 修改。" -ForegroundColor Yellow
} elseif ($hasOldOmp -or $hasOmpCache -or $hasOmpStreaming -or $hasOmpKeyHandler) {
    Write-Host "检测到已有 oh-my-posh 配置:" -ForegroundColor Yellow
    if ($hasOldOmp)    { Write-Host "  - oh-my-posh init 命令" }
    if ($hasOmpCache)  { Write-Host "  - 缓存目录配置" }
    if ($hasOmpStreaming) { Write-Host "  - Enable-PoshStreaming" }
    if ($hasOmpKeyHandler) { Write-Host "  - Enable-KeyHandlers" }

    # 找出将要移除的行
    $lines = $existing -split "`r?`n"
    $toRemove = $lines | Where-Object {
        $_ -match 'oh-my-posh\s+init\s+(pwsh|powershell)' -or
        $_ -match '\$ompCacheDir|\$ompInitCache|\.omp-cache' -or
        $_ -match '\$ompConfig.*omp\.json' -or
        $_ -match 'Enable-PoshStreaming' -or
        $_ -match 'Enable-KeyHandlers' -or
        $_ -match '# =+.*oh-my-posh.*=+' -or
        $_ -match '# ---.*缓存|cache' -or
        $_ -match '# ---.*streaming|守护|管道' -or
        $_ -match '# ---.*key.?handler|刷新' -or
        $_ -match 'posh-themes'
    }

    Write-Host ""
    Write-Host "将要移除以下行:" -ForegroundColor Red
    $toRemove | ForEach-Object { Write-Host "  - $_" -ForegroundColor DarkGray }

    $confirmed = $Force
    if (-not $confirmed) {
        $response = Read-Host "`n确认替换? [y/N]"
        $confirmed = $response -match '^[yY]'
    }

    if ($confirmed) {
        # 备份旧 profile
        $backup = "$userProfile.bak-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        Copy-Item $userProfile $backup
        Write-Host "已备份旧 profile -> $backup" -ForegroundColor Gray

        $cleaned = $lines | Where-Object {
            $_ -notmatch 'oh-my-posh\s+init\s+(pwsh|powershell)' -and
            $_ -notmatch '\$ompCacheDir|\$ompInitCache|\.omp-cache' -and
            $_ -notmatch '\$ompConfig.*omp\.json' -and
            $_ -notmatch 'Enable-PoshStreaming' -and
            $_ -notmatch 'Enable-KeyHandlers' -and
            $_ -notmatch '# =+.*oh-my-posh.*=+' -and
            $_ -notmatch '# ---.*缓存|cache' -and
            $_ -notmatch '# ---.*streaming|守护|管道' -and
            $_ -notmatch '# ---.*key.?handler|刷新' -and
            $_ -notmatch 'posh-themes'
        }
        $existing = ($cleaned -join "`n").TrimEnd()
        Set-Content -Path $userProfile -Value "$existing`n`n$profileContent"
        Write-Host "已替换为 thin-omp-pwsh。" -ForegroundColor Green
    } else {
        Write-Host "已取消，未修改 profile。" -ForegroundColor Yellow
    }
} else {
    if ($existing) {
        Add-Content -Path $userProfile -Value "`n$profileContent"
    } else {
        New-Item -ItemType File -Force $userProfile | Out-Null
        Set-Content -Path $userProfile -Value $profileContent
    }
    Write-Host "  -> 已写入 $userProfile" -ForegroundColor Green
}

Write-Host ""
Write-Host "安装完成！重启 PowerShell 或运行以下命令立即生效:" -ForegroundColor Cyan
Write-Host "  . `$PROFILE.CurrentUserAllHosts" -ForegroundColor White
