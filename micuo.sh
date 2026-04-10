#!/bin/bash
# 确保以 root 权限运行
if [ "$EUID" -ne 0 ]; then
  echo "请以 root 权限运行此脚本"
  exit 1
fi

echo "--- 开始安装 Mihomo 服务端 ---"

# 1. 自动检测系统架构
ARCH=$(uname -m)
case $ARCH in
    x86_64)  PLATFORM="amd64" ;;
    aarch64) PLATFORM="arm64" ;;
    armv7l)  PLATFORM="armv7" ;;
    *) echo "暂不支持的架构: $ARCH"; exit 1 ;;
esac
echo "检测到系统架构为: $PLATFORM"

# 2. 获取最新版本下载链接 (使用 GitHub API)
echo "正在获取最新版本信息..."
LATEST_URL=$(curl -s https://api.github.com/repos/MetaCubeX/mihomo/releases/latest | grep "browser_download_url" | grep "linux-$PLATFORM" | grep "gz" | head -n 1 | cut -d '"' -f 4)

if [ -z "$LATEST_URL" ]; then
    echo "获取下载链接失败，请检查网络"
    exit 1
fi

# 3. 下载并解压
echo "正在下载: $LATEST_URL"
curl -L -o mihomo.tar.gz "$LATEST_URL"
mkdir -p ./mihomo_temp
tar -xzf mihomo.tar.gz -C ./mihomo_temp

# 移动二进制文件
mv ./mihomo_temp/mihomo-linux-$PLATFORM* /usr/local/bin/mihomo
chmod +x /usr/local/bin/mihomo
rm -rf mihomo.tar.gz ./mihomo_temp
echo "程序已安装至 /usr/local/bin/mihomo"

# 4. 创建配置目录和基础配置文件
mkdir -p /etc/mihomo
if [ ! -f /etc/mihomo/config.yaml ]; then
    echo "生成初始配置文件..."
    cat <<EOF > /etc/mihomo/config.yaml
# Mihomo 服务端基础配置
listeners:
EOF
fi

# 5. 下载 GeoIP 数据库 (Country.mmdb)
echo "正在下载 GeoIP 数据库..."
curl -L -o /etc/mihomo/Country.mmdb https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geoip.metadb

# 6. 生成 Systemd 服务文件
echo "生成 Systemd 服务..."
cat <<EOF > /etc/systemd/system/mihomo.service
[Unit]
Description=Mihomo Daemon, A rule-based tunnel in Go.
After=network-online.target

[Service]
Type=simple
Restart=always
User=root
ExecStart=/usr/local/bin/mihomo -d /etc/mihomo
LimitNOFILE=49152

[Install]
WantedBy=multi-user.target
EOF

# 7. 启动服务
systemctl daemon-reload
systemctl enable mihomo
systemctl start mihomo

echo "--- 安装完成 ---"
echo "状态: $(systemctl is-active mihomo)"
echo "配置文件: /etc/mihomo/config.yaml"
echo "修改完配置后运行systemctl restart mihomo"
