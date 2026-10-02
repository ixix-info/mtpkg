#!/system/bin/sh
# mtpkg bootstrap
# 用法: curl -fsSL <URL> | sh

set -e

MT_HOME="$HOME"
MT_LIB="$(dirname "$HOME")/lib"
MT_BASH="$(dirname "$HOME")/bin/bash"

PKG_ROOT="$MT_HOME/pkgs"
BIN_DIR="$MT_HOME/bin"

echo "[mtpkg] bootstrap"

if [ ! -x "$MT_BASH" ]; then
    echo "[mtpkg] ERROR: MT Manager bash not found at $MT_BASH"
    exit 1
fi

mkdir -p "$BIN_DIR" \
         "$PKG_ROOT/recipes" \
         "$PKG_ROOT/patches" \
         "$PKG_ROOT/cache" \
         "$MT_HOME/tmp/build"

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

cat > "$BIN_DIR/mtpkg" << LAUNCHER
#!$MT_BASH
export LD_LIBRARY_PATH="\$HOME/toolchain/files/usr/lib:\$HOME/lib:$MT_LIB:\$LD_LIBRARY_PATH"
exec "\$HOME/toolchain/files/usr/bin/python3" "\$HOME/bin/mtpkg.py" "\$@"
LAUNCHER

chmod +x "$BIN_DIR/mtpkg" "$BIN_DIR/mtpkg.py"

if ! grep -q 'export PATH="$HOME/bin:' "$MT_HOME/.bashrc" 2>/dev/null; then
    echo 'export PATH="$HOME/bin:$PATH"' >> "$MT_HOME/.bashrc"
fi

echo "[mtpkg] installed"
echo "    run: mtpkg install tree"
