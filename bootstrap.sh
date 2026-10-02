#!/system/bin/sh
# mtpkg bootstrap
# 用法: curl -fsSL <URL> | sh

set -e

MT_HOME="$HOME"
PKG_ROOT="$MT_HOME/pkgs"
BIN_DIR="$MT_HOME/bin"
TOOLCHAIN_BIN="$MT_HOME/toolchain/files/usr/bin"

echo "[mtpkg] bootstrap"

mkdir -p "$BIN_DIR" \
         "$PKG_ROOT/recipes" \
         "$PKG_ROOT/patches" \
         "$PKG_ROOT/cache" \
         "$MT_HOME/tmp/build"

# 优先用 ghproxy 加速 GitHub raw
GH_PROXY="https://ghproxy.net/"
REPO_RAW="https://raw.githubusercontent.com/ixix-info/mtpkg/main"

fetch() {
    local path="$1" dest="$2"
    if curl -fsSL --connect-timeout 8 "${GH_PROXY}${REPO_RAW}/${path}" -o "$dest" 2>/dev/null; then
        return 0
    fi
    if curl -fsSL --connect-timeout 12 "${REPO_RAW}/${path}" -o "$dest" 2>/dev/null; then
        return 0
    fi
    return 1
}

fetch "mtpkg.py" "$BIN_DIR/mtpkg.py" || { echo "[mtpkg] failed to fetch mtpkg.py"; exit 1; }
fetch "recipes/index.toml" "$PKG_ROOT/recipes/index.toml" || true

cat > "$BIN_DIR/mtpkg" << 'LAUNCHER'
#!/data/data/bin.mt.plus/files/term/bin/bash
export LD_LIBRARY_PATH="$HOME/toolchain/files/usr/lib:$HOME/lib:/data/data/bin.mt.plus/files/term/lib:$LD_LIBRARY_PATH"
exec "$HOME/toolchain/files/usr/bin/python3" "$HOME/bin/mtpkg.py" "$@"
LAUNCHER

chmod +x "$BIN_DIR/mtpkg" "$BIN_DIR/mtpkg.py"

if ! grep -q 'export PATH="$HOME/bin:' "$MT_HOME/.bashrc" 2>/dev/null; then
    echo 'export PATH="$HOME/bin:$PATH"' >> "$MT_HOME/.bashrc"
fi

if [ ! -x "$TOOLCHAIN_BIN/python3" ]; then
    echo "[mtpkg] warning: python3 not found in toolchain"
    echo "         run 'mtpkg install tc-python' first (once tc packages are published)"
fi

echo "[mtpkg] installed"
echo "    run: mtpkg install tree"
