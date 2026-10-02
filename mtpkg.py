#!/usr/bin/env python3
"""
mtpkg — TOML-driven package manager for Android/MT environment.
Logic in Python, heavy lifting delegated to shell tools.
"""

import os
import re
import sys
import shutil
import subprocess
import tarfile
from pathlib import Path

try:
    import tomllib
except ImportError:
    import toml as tomllib  # 兼容旧版 Python

# ---------- 路径常量 ----------
HOME = Path.home()
PKG_ROOT = HOME / "pkgs"
BUILD_DIR = HOME / "tmp/build"
BIN_DIR = HOME / "bin"
TOOLCHAIN = HOME / "toolchain/files/usr"
TOOLCHAIN_LIB = TOOLCHAIN / "lib"
MT_BASH = Path("/data/data/bin.mt.plus/files/term/bin/bash")
GH_PROXY = "https://ghproxy.net/"

SYSTEM_LIBS = {"libc.so", "libdl.so", "libm.so", "liblog.so"}


# ---------- 工具函数 ----------
def run(cmd, cwd=None, env=None, check=True):
    """统一执行外部命令，自动捕获并打印错误。"""
    result = subprocess.run(
        cmd, cwd=cwd, env=env,
        capture_output=True, text=True
    )
    if check and result.returncode != 0:
        print(f" 命令失败 (exit {result.returncode}): {' '.join(str(c) for c in cmd)}")
        if result.stdout:
            print("--- stdout ---")
            print(result.stdout)
        if result.stderr:
            print("--- stderr ---")
            print(result.stderr)
        sys.exit(1)
    return result.stdout


def load_recipe(name: str) -> dict:
    """从 ~/pkgs/recipes/<name>.toml 加载配方。"""
    path = PKG_ROOT / "recipes" / f"{name}.toml"
    if not path.exists():
        print(f" 找不到配方: {path}")
        sys.exit(1)
    with path.open("rb") as f:
        return tomllib.load(f)


def download(url: str, dest: Path):
    """下载源码包，GitHub 自动走代理。"""
    if dest.exists() and dest.stat().st_size > 0:
        print(f"  (已存在 {dest.name}，跳过下载)")
        return
    if "github.com" in url and GH_PROXY:
        url = GH_PROXY + url
    print(f"➜ 下载: {url}")
    run(["curl", "-L", "--retry", "3", "--connect-timeout", "15",
         "-C", "-", "-o", str(dest), url])


def extract(archive: Path, target_dir: Path) -> Path:
    """解压 tar.gz / tar.xz，返回解压后的源码根目录。"""
    print(f"➜ 解压: {archive.name}")
    target_dir.mkdir(parents=True, exist_ok=True)
    try:
        with tarfile.open(archive) as tf:
            tf.extractall(target_dir)
    except tarfile.TarError as e:
        print(f" 解压失败: {e}")
        sys.exit(1)

    # 找到解压出来的第一层目录（通常是 <name>-<version>）
    subdirs = [d for d in target_dir.iterdir()
               if d.is_dir() and d.name != archive.stem]
    return subdirs[0] if subdirs else target_dir


def apply_patches(src_dir: Path, patch_names: list, pkg_name: str):
    """执行 ~/pkgs/patches/<name>/pre_build.sh。"""
    for patch_name in patch_names:
        patch_script = PKG_ROOT / "patches" / patch_name / "pre_build.sh"
        if not patch_script.exists():
            print(f"  (未找到补丁 {patch_name}，跳过)")
            continue
        print(f"➜ 应用补丁: {patch_name}")
        run(["bash", str(patch_script)], cwd=src_dir)


def build_env(pkg_name: str) -> dict:
    """给编译进程准备的干净环境（不污染当前 shell）。"""
    env = os.environ.copy()
    env["CC"] = str(BIN_DIR / "mt-clang")
    env["CFLAGS"] = "-D_GNU_SOURCE -O2"
    env["PREFIX"] = str(PKG_ROOT / pkg_name)
    env["AR"] = str(TOOLCHAIN / "bin/llvm-ar")
    env["RANLIB"] = str(TOOLCHAIN / "bin/llvm-ranlib")
    env["STRIP"] = str(TOOLCHAIN / "bin/llvm-strip")
    env["LD"] = str(TOOLCHAIN / "bin/ld.lld")
    env["LD_LIBRARY_PATH"] = (
        f"{TOOLCHAIN_LIB}:{HOME / 'lib'}:"
        f"/data/data/bin.mt.plus/files/term/lib:"
        + env.get("LD_LIBRARY_PATH", "")
    )
    return env


def collect_deps(binary, pkg_name):
    print(f"➜ 分析依赖: {binary.name}")
    readelf = TOOLCHAIN / "bin/llvm-readelf"
    out = run([str(readelf), "-d", str(binary)], check=False)
    needed = re.findall(r"Shared library: \[([^\]]+)\]", out)
    
    lib_dir = PKG_ROOT / pkg_name / "lib"
    lib_dir.mkdir(parents=True, exist_ok=True)
    
    copied = 0
    for lib in needed:
        if lib in SYSTEM_LIBS:
            continue
        # ... 复制逻辑 ...
        copied += 1
    
    if copied == 0:
        print("  (仅依赖系统库，无需打包额外 .so)")


def write_wrapper(pkg_name: str, bin_name: str):
    """生成 ~/bin/<name> 包装脚本。"""
    wrapper = BIN_DIR / pkg_name
    content = (
        f"#!{MT_BASH}\n"
        f'export LD_LIBRARY_PATH="{PKG_ROOT / pkg_name / "lib"}:$LD_LIBRARY_PATH"\n'
        f'exec "{PKG_ROOT / pkg_name / "bin" / bin_name}" "$@"\n'
    )
    wrapper.write_text(content)
    wrapper.chmod(0o755)


# ---------- 主流程 ----------
def cmd_install(name: str):
    recipe = load_recipe(name)
    pkg = recipe["package"]
    build = recipe.get("build", {})
    install = recipe.get("install", {})

    bin_name = install.get("bin", name)
    src_url = pkg["url"]

    # 1. 准备构建目录
    work_dir = BUILD_DIR / name
    work_dir.mkdir(parents=True, exist_ok=True)

    # 2. 下载
    archive = work_dir / (name + (".tar.xz" if src_url.endswith(".tar.xz") else ".tar.gz"))
    download(src_url, archive)

    # 3. 解压
    src_dir = extract(archive, work_dir)

    # 4. 打补丁
    apply_patches(src_dir, pkg.get("patches", []), name)

    # 5. 编译
    print("➜ 开始编译...")
    env = build_env(name)
    if build.get("cflags"):
        env["CFLAGS"] = build["cflags"]
    run(["bash", "-c", build["cmd"]], cwd=src_dir, env=env)

    # 6. 定位编译产物
    bin_dir = PKG_ROOT / name / "bin"
    bin_dir.mkdir(parents=True, exist_ok=True)
    candidates = [
        src_dir / bin_name,
        src_dir / "src" / bin_name,
        bin_dir / bin_name,
    ]
    binary_src = next((c for c in candidates if c.exists()), None)
    if binary_src is None:
        print(f" 找不到编译产物: {bin_name}")
        print("   已检查:")
        for c in candidates:
            print(f"     - {c}")
        sys.exit(1)

    if binary_src != bin_dir / bin_name:
        shutil.copy2(binary_src, bin_dir / bin_name)

    # 7. 打包依赖
    print("➜ 提取动态依赖...")
    collect_deps(bin_dir / bin_name, name)

    # 8. 生成包装脚本
    write_wrapper(name, bin_name)
    print(f" {name} 安装完成")


def cmd_list():
    for p in sorted(PKG_ROOT.iterdir()):
        if p.is_dir() and p.name not in {"recipes", "patches"}:
            print(p.name)


def main():
    if len(sys.argv) < 2:
        print("用法: mtpkg install <名称>")
        print("      mtpkg list")
        sys.exit(1)

    action = sys.argv[1]
    if action == "install":
        cmd_install(sys.argv[2])
    elif action == "list":
        cmd_list()
    else:
        print(f" 未知命令: {action}")
        sys.exit(1)


if __name__ == "__main__":
    main()