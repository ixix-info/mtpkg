#!/system/bin/sh
# mtpkg bootstrap
# 用法: curl -fsSL <URL> | sh

set -e

MT_HOME="$HOME"
MT_LIB="$(dirname "$HOME")/lib"
MT_BASH="$(dirname "$HOME")/bin/bash"
MT_BIN="$(dirname "$HOME")/bin"

PKG_ROOT="$MT_HOME/pkgs"
BIN_DIR="$MT_HOME/bin"
TOOLCHAIN="$MT_HOME/toolchain/files/usr"

echo "[mtpkg] bootstrap"

if [ ! -x "$MT_BASH" ]; then
    echo "[mtpkg] ERROR: MT Manager bash not found at $MT_BASH"
    exit 1
fi

mkdir -p "$BIN_DIR" \
         "$PKG_ROOT/recipes" \
         "$PKG_ROOT/patches" \
         "$PKG_ROOT/cache" \
         "$TOOLCHAIN" \
         "$MT_HOME/tmp/build"

GH_PROXY="https://ghproxy.net/"
REPO_RAW="https://raw.githubusercontent.com/ixix-info/mtpkg/main"
RELEASE="https://github.com/ixix-info/mtpkg/releases/download/toolchain-v1"

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

fetch_shard() {
    local name="$1"
    local dest="$MT_HOME/tmp/${name}.tar.gz"
    if [ ! -f "$dest" ]; then
        echo "[mtpkg] downloading $name"
        curl -L --retry 3 --connect-timeout 15 -C - \
             -o "$dest" "${GH_PROXY}${RELEASE}/${name}.tar.gz"
    fi
    echo "[mtpkg] extracting $name"
    tar -xzf "$dest" -C "$TOOLCHAIN"
}

fetch "mtpkg.py" "$BIN_DIR/mtpkg.py" || { echo "[mtpkg] failed to fetch mtpkg.py"; exit 1; }
fetch "recipes/index.toml" "$PKG_ROOT/recipes/index.toml" || true

# 首次安装：只拉 tc-base 和 tc-python-stdlib (约 20MB)
if [ ! -x "$TOOLCHAIN/bin/python3" ]; then
    echo "[mtpkg] installing base toolchain (about 20MB)"
    fetch_shard "tc-base"
    fetch_shard "tc-python-stdlib"
else
    echo "[mtpkg] base toolchain already present"
fi

cat > "$BIN_DIR/mtpkg" << LAUNCHER
#!$MT_BASH
export LD_LIBRARY_PATH="\$HOME/toolchain/files/usr/lib:\$HOME/lib:$MT_LIB:\$LD_LIBRARY_PATH"
exec "\$HOME/toolchain/files/usr/bin/python3" "\$HOME/bin/mtpkg.py" "\$@"
LAUNCHER

chmod +x "$BIN_DIR/mtpkg" "$BIN_DIR/mtpkg.py"

if ! grep -q 'export PATH="\$HOME/bin:' "$MT_HOME/.bashrc" 2>/dev/null; then
    echo 'export PATH="$HOME/bin:$PATH"' >> "$MT_HOME/.bashrc"
fi

echo "[mtpkg] installed"
echo "    try: mtpkg list"
echo "    first compile: mtpkg install tree   (will download toolchain automatically)"
