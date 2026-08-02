# ============================================================
# PowerShell profile — 极速 oh-my-posh (streaming + init 缓存)
# 优化点：
#   1. 缓存 init 脚本，跳过每次启动 fork oh-my-posh.exe（省 ~1s）
#   2. Enable-PoshStreaming 常驻 serve 守护进程，每次回车渲染 0.1-2.6ms
# 配置文件改动后自动重建缓存
# ============================================================

$ompConfig =  Join-Path $HOME '\Documents\PowerShell\posh-themes\thin.omp.json'
$ompCacheDir = Join-Path $HOME '.omp-cache'
$ompInitCache = Join-Path $ompCacheDir 'init.ps1'

# --- 缓存 init 脚本：配置 mtime 变化或缓存缺失时才重新生成 ---
$needRebuild = $true
if (Test-Path $ompInitCache) {
    $cacheTime = (Get-Item $ompInitCache).LastWriteTime
    $cfgTime = (Get-Item $ompConfig).LastWriteTime
    if ($cacheTime -ge $cfgTime) { $needRebuild = $false }
}

if ($needRebuild) {
    if (-not (Test-Path $ompCacheDir)) { New-Item -ItemType Directory -Path $ompCacheDir -Force | Out-Null }
    # --print 输出完整 init 脚本，缓存到固定文件
    oh-my-posh init pwsh --print --config $ompConfig | Out-File -FilePath $ompInitCache -Encoding utf8
}

. $ompInitCache

# --- 开启 streaming 模式（常驻守护进程，关键优化）---
# 启动一个 oh-my-posh serve 进程常驻内存，之后每次 prompt 渲染走管道
if (Get-Command Enable-PoshStreaming -ErrorAction Ignore) {
    Enable-PoshStreaming
}
# Enable-KeyHandlers 是 streaming 正确刷新的前提：
# 每次按 Enter 时重置渲染状态，避免 prompt 被永久缓存
if (Get-Command Enable-KeyHandlers -ErrorAction Ignore) {
    Enable-KeyHandlers
}
