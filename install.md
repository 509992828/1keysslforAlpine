#!/bin/sh
#================================================
# 脚本名称: install.sh (一键执行引导脚本)
#================================================

# 请替换为您的 GitHub 用户名和仓库名
REPO_RAW_URL="https://raw.githubusercontent.com/509992828/1keysslforAlpine/main"
MAIN_SCRIPT="main.sh"
TEMP_DIR="/tmp/cf_ssl_installer"

# --- 1. 环境检查与依赖安装 (针对 Alpine) ---
echo "--- 1. 检查操作系统和安装依赖 ---"

if [ -f "/etc/alpine-release" ]; then
    echo "✅ 检测到 Alpine Linux，开始安装依赖 (bash, git, curl, socat, openssl)..."
    apk update
    apk add curl socat openssl git bash
    if [ $? -ne 0 ]; then
        echo "❌ 依赖安装失败，请检查网络！"
        exit 1
    fi
else
    echo "⚠️ 警告：当前系统不是 Alpine Linux，但仍尝试执行。请确保依赖已手动安装。"
fi

# --- 2. 下载主脚本 ---
echo "--- 2. 下载主脚本 ($MAIN_SCRIPT) ---"
mkdir -p "$TEMP_DIR"
curl -fsSL "$REPO_RAW_URL/src/$MAIN_SCRIPT" -o "$TEMP_DIR/$MAIN_SCRIPT"

if [ $? -ne 0 ]; then
    echo "❌ 主脚本下载失败，请检查 GitHub 地址是否正确。"
    rm -rf "$TEMP_DIR"
    exit 1
fi

chmod +x "$TEMP_DIR/$MAIN_SCRIPT"

# --- 3. 执行主脚本 ---
echo "--- 3. 启动证书申请向导 ---"
# 使用 bash 执行主脚本，以保证语法兼容性
bash "$TEMP_DIR/$MAIN_SCRIPT"

echo "🎉 脚本执行完毕。请根据上面提示检查证书是否申请成功。"