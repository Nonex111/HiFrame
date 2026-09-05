<p align="center">
  <img src="Packaging/Assets/SteadyFrame-AppIcon-v3.png" width="128" alt="HiFrame 应用图标">
</p>

<h1 align="center">HiFrame</h1>

<p align="center">
  面向 ProMotion MacBook 的高刷新率辅助工具，尝试缓解低亮度灰色画面中的可见频闪。
</p>

<p align="center">
  <a href="README.md">English</a> · <strong>简体中文</strong>
</p>

<p align="center">
  <a href="downloads/HiFrame.zip?raw=true"><strong>⬇ 下载 HiFrame macOS 版</strong></a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-13%2B-111111?logo=apple&logoColor=white" alt="macOS 13+">
  <img src="https://img.shields.io/badge/status-preview-3B82F6" alt="预览版">
</p>

HiFrame 是一款面向 ProMotion MacBook Pro 的轻量 macOS 菜单栏工具。它持续呈现一个几乎不可见的 1 × 1 逻辑点 Metal 表面，在画面静止时持续请求 60 或 120 fps 的呈现调度。

这可能缓解部分用户在低亮度、深灰色区域观察到的可见频闪与视觉不适。

应用可直接从菜单栏选择**跟随系统**、**English** 或**简体中文**。预览版使用临时签名且尚未经过 Apple 公证，首次启动时可能需要在**系统设置 → 隐私与安全性**中批准打开。

> [!IMPORTANT]
> HiFrame 请求的是呈现节奏。它不会修改 macOS 显示模式、测量面板物理刷新率，也不保证将面板锁定在 120 Hz。实际效果会因 Mac 型号、macOS 版本、画面内容、电源状态和观察者而异。

## 主要功能

- 保留 ProMotion 的同时，请求 60 或 120 fps 调度。
- 支持始终运行或仅接通电源时运行。
- 可在低于指定电量后自动暂停。
- 可选择仅内置屏幕或所有已连接屏幕。
- 使用固定且极小的 8/255 帧间亮度差。
- 信号位置可选左下角、右下角或中间。
- 可从菜单栏切换跟随系统、English 与简体中文。
- 可选开机自启动：登录 macOS 后自动在菜单栏启动，默认关闭。
- 支持手动检查更新，并自动提示新的正式版本。
- 支持全局快捷键 `⌃⌥⌘H`，并可从菜单栏复制运行诊断。

## 开机自启动

在菜单栏勾选**开机自启动**即可启用，登录 macOS 用户账户后应用会自动启动，再次点击可取消。若显示待批准，请点击**前往系统设置批准…**；待批准时再次点击开关会取消注册。菜单每次打开都会读取系统的实际状态。自启动仍遵循已有的启用状态、电源策略和低电量保护。

请先将 `HiFrame.app` 放在固定位置（建议“应用程序”文件夹），再开启自启动；直接使用 `swift run` 不支持设置登录项。

## 检查更新

可随时从菜单栏选择**检查更新…**。应用也会在启动后及持续运行期间后台检查 GitHub Releases，每 24 小时最多检查一次。每个新的正式版本只自动提示一次；手动检查始终显示结果。后台失败保持安静，手动检查失败时可前往发布页面。新版提示会显示当前版本与最新版本，并提供发布页下载入口，安装由用户手动完成。

## 系统要求

- macOS 13 或更高版本
- 目标使用场景需要配备 ProMotion 显示屏的 MacBook Pro
- 从源码构建时需要兼容 Swift 5.10 的工具链与 macOS SDK

## 从源码构建

如需自行构建：

```bash
swift test
./scripts/build-app.sh
open dist/HiFrame.app
```

HiFrame 仅显示在菜单栏中。首次启动默认启用 120 fps，仅作用于内置屏幕，信号位于屏幕中间，并在接通电源时运行，低电量停止阈值为 20%。
