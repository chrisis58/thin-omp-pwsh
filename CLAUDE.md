# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

极简、高性能的 oh-my-posh PowerShell 主题。两行 prompt：第一行路径 + 执行耗时，第二行 `❯❯` 提示符（成功白色，失败红色）。

核心创新在于 **profile.ps1** 的性能基础设施，而非主题 JSON 本身——init 缓存、streaming 守护进程、key handlers 与主题解耦，可用于任何 oh-my-posh 配置。

## 文件架构

| 文件 | 职责 |
|------|------|
| `thin.omp.json` | oh-my-posh v4 主题配置。plain 风格，无 Powerline 符号，跨 shell 通用。 |
| `profile.ps1` | PowerShell profile。三项功能：init 脚本缓存、`Enable-PoshStreaming`、`Enable-KeyHandlers`。通过 `$PROFILE` dot-source 加载。 |
| `install.ps1` | 远程安装脚本，通过 GitHub raw 分发。下载上述两个文件，写入 `$PROFILE.CurrentUserAllHosts`，自动检测旧配置并备份。 |
| `README.md` | 用户文档（中文）。尚未提交，作为工作区变更保留。 |

## 关键约束

- **install.ps1 必须是纯 ASCII 字符。** 任何非 ASCII 字符（em dash、中文等）在 `iwr | iex` 管道中会乱码。此文件只能使用 ASCII。
- **Streaming 需要 PS6+。** profile 使用 `Get-Command Enable-PoshStreaming -ErrorAction Ignore` 守卫，在 Windows PowerShell 5.1 上静默降级（仅 init 缓存生效）。

## profile.ps1 缓存机制

1. 比较 `$ompInitCache` 与 `$ompConfig` 的 mtime。
2. 缓存缺失或过期 → 执行 `oh-my-posh init pwsh --print --config $ompConfig`，输出写入 `$HOME\.omp-cache\init.ps1`。
3. 直接 dot-source 缓存文件——跳过每次启动 fork exe 的 ~80ms 开销。
4. 随后调用 `Enable-PoshStreaming`（启动 `oh-my-posh serve` 守护进程）和 `Enable-KeyHandlers`（在 Enter 时重置 streaming 状态）。

## install.ps1 设计

- 从同一 GitHub 仓库/分支下载 `thin.omp.json` 和 `profile.ps1`。
- 同时检查 `$PROFILE`（宿主专用）和 `$PROFILE.CurrentUserAllHosts` 中的旧 oh-my-posh 配置。
- 若 `CurrentUserAllHosts` 中发现旧配置：预览待删除行 → 提示确认（`-Force` 跳过）→ 备份旧 profile（带时间戳）→ 写入新配置。
- 若仅在宿主专用 profile 中发现旧配置：仅警告，不自动修改。

## 主题路径

默认路径（修改时需同时更新两个文件保持同步）：

| 文件 | 变量 | 默认值 |
|------|------|--------|
| `profile.ps1` | `$ompConfig` | `$HOME\Documents\PowerShell\posh-themes\thin.omp.json` |
| `profile.ps1` | `$ompCacheDir` | `$HOME\.omp-cache` |
| `install.ps1` | `$themeDir` | `$HOME\Documents\PowerShell\posh-themes` |
