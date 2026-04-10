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

# 3. 核心逻辑：生成 Reality 密钥对
generate_keys() {
    echo -e "${BLUE}正在生成 Reality 密钥对...${NC}"
    # 使用 mihomo 内置命令生成密钥
    KEYS=$($INSTALL_PATH x25519)
    # 提取私钥和公钥 (假设输出格式为 Private key: xxx / Public key: yyy)
    PRI_KEY=$(echo "$KEYS" | grep "Private key" | awk '{print $3}')
    PUB_KEY=$(echo "$KEYS" | grep "Public key" | awk '{print $3}')
}

# 4. 用户交互输入
user_input() {
    echo -e "${BLUE}--- 请输入配置信息 ---${NC}"
    read -p "1. 监听名称 (name, 默认 vless-in-1): " NAME
    NAME=${NAME:-vless-in-1}

    read -p "2. 监听地址 (listen, 默认 0.0.0.0): " LISTEN
    LISTEN=${LISTEN:-0.0.0.0}

    read -p "3. 监听端口 (port, 默认 24289): " PORT
    PORT=${PORT:-24289}

    read -p "4. 目标地址 (dest, 默认 addons.mozilla.org:443): " DEST
    DEST=${DEST:-addons.mozilla.org:443}

    read -p "5. 域名列表 (server-names, 多个用空格隔开, 默认 addons.mozilla.org): " SNIS
    SNIS=${SNIS:-addons.mozilla.org}
    
    # 将空格分隔的域名转为 YAML 列表格式
    SNI_YAML=""
    for sni in $SNIS; do
        SNI_YAML="$SNI_YAML      - $sni\n"
    done

    # 自动生成 UUID 和 ShortID
    UUID=$(cat /proc/sys/kernel/random/uuid)
    SHORT_ID=$(openssl rand -hex 6)
}

# 5. 写入配置
write_config() {
    mkdir -p $CONFIG_DIR
    cat <<EOF > $CONFIG_DIR/config.yaml
log-level: info
ipv6: false
allow-lan: true

listeners:
  - name: $NAME
    listen: $LISTEN
    port: $PORT
    type: vless
    reality-config:
      dest: $DEST
      private-key: $PRI_KEY
      server-names:
$(echo -e "$SNI_YAML" | sed 's/\\n//g')
      short-id:
        - $SHORT_ID
    users:
      - flow: xtls-rprx-vision
        username: user1
        uuid: $UUID
EOF
}

# 6. 设置服务并启动
setup_service() {
    cat <<EOF > /etc/systemd/system/mihomo.service
[Unit]
Description=Mihomo Reality Service
After=network.target

[Service]
Type=simple
ExecStart=$INSTALL_PATH -d $CONFIG_DIR
Restart=always
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable mihomo --now &> /dev/null
    systemctl restart mihomo
}

# --- 执行流程 ---
install_mihomo
generate_keys
user_input
write_config
setup_service

echo -e "\n${GREEN}==========================================${NC}"
echo -e "${GREEN}部署成功！以下是你的客户端连接信息：${NC}"
echo -e "${BLUE}UUID:${NC} $UUID"
echo -e "${BLUE}Public Key:${NC} $PUB_KEY"
echo -e "${BLUE}Short ID:${NC} $SHORT_ID"
echo -e "${BLUE}Port:${NC} $PORT"
echo -e "${BLUE}SNI:${NC} $(echo $SNIS | awk '{print $1}')"
echo -e "${GREEN}==========================================${NC}"