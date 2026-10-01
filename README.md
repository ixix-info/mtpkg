# mtpkg

一个用于 Android 的自托管软件包管理器，基于 Termux 工具链和 Bionic libc 构建。
运行在 MT 管理器的终端环境中，支持从源码编译、打补丁、提取依赖、打包安装。

## 特性

- **自举**：只需几百 KB 的引导脚本，工具链按需拉取
- **Bionic 原生**：所有二进制为 Android 平台编译，不依赖 glibc
- **TOML 配方**：声明式描述包，Python + Shell 双层架构
- **隔离打包**：每个包自包含动态库，互不污染

## 快速开始

\`\`\`sh
curl -fsSL https://gitee.com/iki-info/mtpkg/raw/main/bootstrap.sh | sh
mtpkg install tree
\`\`\`

## 目录结构

- `mtpkg.py` — 主逻辑（Python）
- `bootstrap.sh` — 引导脚本
- `recipes/` — 包配方（TOML）
- `patches/` — 平台适配补丁
- `dist/` — 预编译产物（放在 CDN，不进 Git）

## License

MIT
