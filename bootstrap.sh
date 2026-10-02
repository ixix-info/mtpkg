#!/system/bin/sh
# mtpkg bootstrap
# 用法: curl -fsSL <URL> | sh

set -e

MT_HOME="$HOME"
PKG_ROOT="$MT_HOME/pkgs"
BIN_DIR="$MT_HOME/bin"

echo "[mtpkg] bootstrap"

mkdir -p "$BIN_DIR" \
         "$PKG_ROOT/recipes" \
         "$PKG_ROOT/patches" \
         "$PKG_ROOT/cache" \
         "$MT_HOME/tmp/build"

GITEE="https://gitee.com/ixix-info/mtpkg/raw/main"
GITHUB="https://raw.githubusercontent.com/ixix-info/mtpkg/main"

if curl -fsSL --connect-timeout 5 "$GITEE/mtpkg.py" -o "$BIN_DIR/mtpkg.py" 2>/dev/null; then
    echo "[mtpkg] fetched mtpkg.py from Gitee"
elif curl -fsSL --connect-timeout 10 "$GITHUB/mtpkg.py" -o "$BIN_DIR/mtpkg.py" 2>/dev/null; then
    echo "[mtpkg] fetched mtpkg.py from GitHub"
else
    echo "[mtpkg] download failed"
    exit 1
fi

curl -fsSL "$GITEE/recipes/index.toml" -o "$PKG_ROOT/recipes/index.toml" 2>/dev/null || \
curl -fsSL "$GITHUB/recipes/index.toml" -o "$PKG_ROOT/recipes/index.toml"

cat > "$BIN_DIR/mtpkg" << 'LAUNCHER'
#!/data/data/bin.mt.plus/files/term/bin/bash
export LD_LIBRARY_PATH="$HOME/toolchain/files/usr/lib:$HOME/lib:/data/data/bin.mt.plus/files/term/lib:$LD_LIBRARY_PATH"
exec "$HOME/toolchain/files/usr/bin/python3" "$HOME/bin/mtpkg.py" "$@"
LAUNCHER

chmod +x "$BIN_DIR/mtpkg" "$BIN_DIR/mtpkg.py"

if ! grep -q 'export PATH="$HOME/bin:' "$MT_HOME/.bashrc" 2>/dev/null; then
    echo 'export PATH="$HOME/bin:$PATH"' >> "$MT_HOME/.bashrc"
fi

echo "[mtpkg] installed"
echo "    run: mtpkg install tree"
