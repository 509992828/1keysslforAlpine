#!/bin/bash
#================================================
# 脚本名称: main.sh (核心证书申请逻辑)
# 环境: 专为由 install.sh 引导的 Alpine/Linux 环境设计
# 功能: 交互式收集配置，使用 acme.sh 和 Cloudflare DNS API 申请 ECC 证书并部署。
#================================================

# 确保使用 bash (由 install.sh 确保安装)
if [ -z "$BASH_VERSION" ]; then
    echo "❌ 错误: 请使用 bash 执行本脚本。"
    exit 1
fi

# 确保 acme.sh 路径可用
ACME_SH="$HOME/.acme.sh/acme.sh"

# --- 1. 检查 acme.sh 是否已安装 ---
if [ ! -f "$ACME_SH" ]; then
    echo "❌ 错误: acme.sh 未找到。请确保 install.sh 脚本已成功执行并安装了 acme.sh。"
    exit 1
fi

# --- 2. 交互式输入配置项 ---
echo "================================================="
echo "  Cloudflare DNS 模式 SSL 证书申请向导"
echo "  (请确保您的域名已使用 Cloudflare DNS 解析)"
echo "================================================="

# 询问域名
read -p "1. 请输入您的主域名 (例如: jp.example.com): " DOMAIN
if [ -z "$DOMAIN" ]; then
    echo "域名不能为空。" ; exit 1
fi

# 询问 LE 邮箱
read -p "2. 请输入您的通知邮箱 (用于 Let's Encrypt 通知): " LE_EMAIL
if [ -z "$LE_EMAIL" ]; then
    echo "邮箱不能为空。" ; exit 1
fi

# 询问 CF 邮箱
read -p "3. 请输入您的 Cloudflare 注册邮箱: " CF_EMAIL
if [ -z "$CF_EMAIL" ]; then
    echo "CF 邮箱不能为空。" ; exit 1
fi

# 询问 CF Key
echo "请注意: CF_KEY 是 Cloudflare Global API Key，请在 CF 个人资料的 API Tokens 页面获取。"
read -p "4. 请输入您的 Cloudflare Global API Key: " CF_KEY
if [ -z "$CF_KEY" ]; then
    echo "CF Key 不能为空。" ; exit 1
fi

# 询问证书部署目录
DEFAULT_CERT_DIR="/etc/v2ray/ssl"
read -p "5. 请输入证书部署目录 (默认: $DEFAULT_CERT_DIR): " CERT_DIR
CERT_DIR=${CERT_DIR:-$DEFAULT_CERT_DIR} # 使用默认值

# 询问服务重启命令
DEFAULT_RELOAD_CMD="echo '请手动重启您的代理服务'"
echo "6. 请输入代理服务重启命令 (例如: rc-service xray restart)。"
read -p "   (默认: $DEFAULT_RELOAD_CMD): " RELOAD_CMD
RELOAD_CMD=${RELOAD_CMD:-$DEFAULT_RELOAD_CMD}

echo "================================================="
echo "配置信息收集完毕，开始证书流程..."
echo "================================================="

# --- 3. 注册 Let's Encrypt 账户 ---
echo "--- 注册/更新 Let's Encrypt 账户 ($LE_EMAIL) ---"
$ACME_SH --register-account -m "$LE_EMAIL"
if [ $? -ne 0 ]; then
    echo "❌ 账户注册失败！"
    exit 1
fi
echo "✅ 账户注册完成。"

# --- 4. 设置 Cloudflare 环境变量并申请证书 ---
echo "--- 设置 Cloudflare API 密钥并申请证书 ($DOMAIN) ---"

# 导出环境变量供 acme.sh 使用
export CF_Email="$CF_EMAIL"
export CF_Key="$CF_KEY"

# 申请 ECC 256 位证书
# --force 可以用于测试，正式运行时应移除
$ACME_SH --issue -d "$DOMAIN" --dns dns_cf --ecc
CERT_STATUS=$?

# 清除环境变量 (安全起见)
unset CF_Email
unset CF_Key

if [ $CERT_STATUS -ne 0 ]; then
    echo "❌ 证书申请失败！请仔细检查您的域名解析和 Cloudflare API 密钥是否正确、权限是否足够。"
    exit 1
fi
echo "✅ 证书申请成功！"

# --- 5. 部署证书并配置自动更新 ---
echo "--- 部署证书到指定目录 ($CERT_DIR) ---"

# 创建证书目录
mkdir -p "$CERT_DIR"

# 部署证书 (fullchain.cer 是证书链，.key 是私钥)
$ACME_SH --install-cert -d "$DOMAIN" --ecc \
--key-file "$CERT_DIR/$DOMAIN.key" \
--fullchain-file "$CERT_DIR/$DOMAIN.cer" \
--reloadcmd "$RELOAD_CMD"

if [ $? -eq 0 ]; then
    echo "🎉 证书部署成功！"
    echo "================================================="
    echo "🚀 证书部署信息:"
    echo "证书路径: $CERT_DIR/$DOMAIN.cer"
    echo "私钥路径: $CERT_DIR/$DOMAIN.key"
    echo "自动重载命令: $RELOAD_CMD"
    echo "================================================="
else
    echo "⚠️ 证书部署失败，请检查 $CERT_DIR 目录权限。证书可能已在 $HOME/.acme.sh/$DOMAIN\_ecc 目录下。"
fi

echo "脚本执行完毕。"
