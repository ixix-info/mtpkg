# mtpkg

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform: Android](https://img.shields.io/badge/Platform-Android-3DDC84.svg)](https://www.android.com/)
[![Python 3.14+](https://img.shields.io/badge/Python-3.14+-blue.svg)](https://www.python.org/)
[![Shell](https://img.shields.io/badge/Shell-Bash-4EAA25.svg)](https://www.gnu.org/software/bash/)

> **非官方项目。** 本项目与 MT 管理器、Termux、Google 无隶属关系。
> 使用前请阅读 [DISCLAIMER.md](DISCLAIMER.md)。

一个适用于 Android 的自托管软件包管理器，基于 Termux 工具链和 Bionic libc 构建。

## 特性

- **自举**：只需几百 KB 的引导脚本，工具链按需拉取
- **Bionic 原生**：所有二进制为 Android 平台编译，不依赖 glibc
- **TOML 配方**：声明式描述包，Python + Shell 双层架构
- **隔离打包**：每个包自包含动态库，互不污染

## 快速开始

    curl -fsSL https://ghproxy.net/https://raw.githubusercontent.com/ixix-info/mtpkg/main/bootstrap.sh | sh
    mtpkg install tree

## 目录结构

- `mtpkg.py` — 主逻辑（Python）
- `bootstrap.sh` — 引导脚本
- `recipes/` — 包配方（TOML）
- `patches/` — 平台适配补丁
- `dist/` — 预编译产物（放在 CDN，不进 Git）

## License

MIT
