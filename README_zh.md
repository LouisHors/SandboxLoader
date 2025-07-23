# SandboxLoader

一个使用 Swift 和 AppKit 构建的 macOS 应用程序，用于浏览 iOS 设备上侧载应用的沙盒。

[English README](README.md)

## 概览

SandboxLoader 提供了一个友好的用户界面，让您可以直接在 Mac 上浏览 iPhone 或 iPad 上的应用程序文件系统。它利用强大的 `libimobiledevice` 库与 iOS 设备通信，使您能够查看、管理和传输文件，而无需越狱。

## 功能

- **设备发现**: 自动检测连接的 iOS 设备。
- **应用列表**: 列出所选设备上安装的所有应用程序。
- **文件系统浏览器**: 一个熟悉的树状视图，用于导航应用的沙盒目录。
- **文件操作**: (计划中) 支持通过拖放导入/导出文件、删除文件和创建文件夹。

## 技术栈

- **UI**: Swift & AppKit
- **核心逻辑**: 一个围绕 `libimobiledevice` C语言库的 Swift 封装层。
- **依赖**: `libimobiledevice` 及其相关工具。

## 如何开始

1.  **克隆仓库。**
2.  **安装依赖**: 确保已安装 `libimobiledevice`，例如通过 Homebrew (`brew install libimobiledevice`)。
3.  **在 Xcode 中打开 `SandboxLoader.xcodeproj`。**
4.  **构建并运行** 项目。
