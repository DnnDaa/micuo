#!/bin/bash

# ==========================================
# 颜色定义
# ==========================================
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

INSTALL_PATH="/usr/local/bin/mihomo"
CONFIG_DIR="/etc/mihomo"

# 1. 权限检查
[[ $EUID -ne 0 ]] && echo -e "${RED}请以 root 权限运行${NC}" && exit 1

# 2. 环境准备与内核下载
install_mihomo() {
    if [ ! -f "$INSTALL_PATH" ]; then
        echo -e "${BLUE}正在下载 Mihomo 内核...${NC}"
        ARCH=$(uname -m)
        case $ARCH in
            x86_64)  FILE_ARCH="amd64" ;;
            aarch64) FILE_ARCH="arm64" ;;
            *) echo "不支持的架构: $ARCH"; exit 1 ;;
        esac
        
        # 获取最新版本并下载 (此处建议根据实际情况更新 URL)

        URL="https://github.com/MetaCubeX/mihomo/releases/download/v1.19.23/mihomo-linux-$FILE_ARCH-v1.19.23.gz"
        wget -qO mihomo.gz $URL && gunzip -c mihomo.gz > $INSTALL_PATH
        chmod +x $INSTALL_PATH
        rm mihomo.gz
        echo -e "${GREEN}内核安装成功！${NC}"
    fi
}

