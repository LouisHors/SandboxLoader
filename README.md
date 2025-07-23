# SandboxLoader

A macOS application to browse the sandboxes of sideloaded apps on iOS devices, built with Swift and AppKit.

[中文说明](README_zh.md)

## Overview

SandboxLoader provides a user-friendly interface to explore the file system of applications on your iPhone or iPad directly from your Mac. It leverages the powerful `libimobiledevice` library to communicate with iOS devices, allowing you to view, manage, and transfer files without needing a jailbreak.

## Features

- **Device Discovery**: Automatically detects connected iOS devices.
- **App Listing**: Lists all installed applications on the selected device.
- **File System Browser**: A familiar tree-based view to navigate the app's sandbox directory.
- **File Operations**: (Planned) Support for drag-and-drop to export/import files, delete files, and create folders.

## Technology Stack

- **UI**: Swift & AppKit
- **Core Logic**: A Swift wrapper around the `libimobiledevice` C-library.
- **Dependencies**: `libimobiledevice` and its related tools.

## Getting Started

1.  **Clone the repository.**
2.  **Install dependencies**: Ensure `libimobiledevice` is installed, for example via Homebrew (`brew install libimobiledevice`).
3.  **Open `SandboxLoader.xcodeproj` in Xcode.**
4.  **Build and run** the project.
