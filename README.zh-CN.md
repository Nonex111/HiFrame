<p align="center">
  <img src="Packaging/Assets/SteadyFrame-AppIcon-v3.png" width="128" alt="SteadyFrame 应用图标">
</p>

<h1 align="center">SteadyFrame</h1>

<p align="center">
  让 MacBook Pro 的 ProMotion 保持更稳定的高刷新率状态，尝试缓解低亮度灰色画面中的可见频闪。
</p>

<p align="center">
  <a href="README.md">English</a> · <strong>简体中文</strong>
</p>

<p align="center">
  <a href="https://github.com/Nonex111/SteadyFrame/releases/latest/download/SteadyFrame.zip"><strong>⬇ 下载 SteadyFrame macOS 版</strong></a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-13%2B-111111?logo=apple&logoColor=white" alt="macOS 13+">
  <img src="https://img.shields.io/badge/status-preview-3B82F6" alt="预览版">
</p>

SteadyFrame 是一款面向 ProMotion MacBook Pro 的轻量 macOS 菜单栏工具。它持续呈现一个几乎不可见的 1 × 1 逻辑点 Metal 表面，让显示管线在画面静止时仍维持稳定的 60 或 120 fps 呈现调度。

这可能缓解部分用户在低亮度、深灰色区域观察到的可见频闪与视觉不适。

应用可直接从菜单栏选择**跟随系统**、**English** 或**简体中文**。预览版使用临时签名且尚未经过 Apple 公证，首次启动时可能需要在**系统设置 → 隐私与安全性**中批准打开。

> [!IMPORTANT]
> SteadyFrame 请求的是呈现节奏。它不会修改 macOS 显示模式、测量面板物理刷新率，也不保证将面板锁定在 120 Hz。实际效果会因 Mac 型号、macOS 版本、画面内容、电源状态和观察者而异。

## 主要功能

- 保留 ProMotion 的同时，请求稳定的 60 或 120 fps 调度。
- 支持始终运行或仅接通电源时运行。
- 可在低于指定电量后自动暂停。
- 可选择仅内置屏幕或所有已连接屏幕。
- 使用固定且极小的 8/255 帧间亮度差。
- 信号位置可选左下角、右下角或中间。
- 可从菜单栏切换跟随系统、English 与简体中文。
- 支持全局快捷键 `⌃⌥⌘H`，并可从菜单栏复制运行诊断。

## 系统要求

- macOS 13 或更高版本
- 目标使用场景需要配备 ProMotion 显示屏的 MacBook Pro
- 从源码构建时需要兼容 Swift 5.10 的工具链与 macOS SDK

## 从源码构建

如需自行构建：

```bash
swift test
./scripts/build-app.sh
open dist/SteadyFrame.app
```

SteadyFrame 仅显示在菜单栏中。首次启动默认启用 120 fps，仅作用于内置屏幕，信号位于屏幕中间，并在接通电源时运行，低电量停止阈值为 20%。
