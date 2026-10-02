#!/data/data/bin.mt.plus/files/term/bin/bash
echo "Applying tree fixes for Android..."

# 1. 删除 tree.h 中引发冲突的 #define _GNU_SOURCE（第19行）
sed -i '19d' tree.h

# 2. 修改条件编译，让 Android 也能看到 strverscmp 的声明
sed -i 's/#ifndef __linux__/#if !defined(__linux__) || defined(__ANDROID__)/' tree.h

# 3. 在 strverscmp.c 开头取消 __linux__ 宏定义，强制编译出实现
sed -i '1i #undef __linux__' strverscmp.c

echo "Fixes applied successfully."
