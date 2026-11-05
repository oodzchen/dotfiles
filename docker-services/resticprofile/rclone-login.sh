#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RCLONE_DIR="$SCRIPT_DIR/rclone"
mkdir -p "$RCLONE_DIR"

echo "=========================================================="
echo "          Google Drive OAuth 登录与配置向导"
echo "=========================================================="
echo "请选择操作："
echo "  1) 快速自动授权 Google Drive (默认，推荐)"
echo "  2) 自定义 Client ID / Secret 或完整交互式 rclone config"
echo "  3) 测试 Google Drive 连接 (查看云盘目录)"
echo "  4) 退出"
echo "=========================================================="
read -r -p "请输入选项 [1-4，默认 1]: " choice
choice="${choice:-1}"

case "$choice" in
  1)
    echo ""
    echo "==> 正在启动 Google Drive OAuth 授权服务..."
    echo "==> 终端即将打印形如 http://127.0.0.1:53682/auth?state=... 的链接"
    echo "==> 请在浏览器中打开该链接，登录 Google 账号并完成授权"
    echo ""
    docker run -it --rm \
      --net=host \
      -v "$RCLONE_DIR:/root/.config/rclone" \
      --entrypoint rclone \
      creativeprojects/resticprofile:latest \
      config create gdrive drive scope=drive config_is_local=true
    ;;
  2)
    echo ""
    echo "==> 启动完整交互式 rclone config..."
    docker run -it --rm \
      --net=host \
      -v "$RCLONE_DIR:/root/.config/rclone" \
      --entrypoint rclone \
      creativeprojects/resticprofile:latest \
      config
    ;;
  3)
    echo ""
    echo "==> 正在测试 Google Drive 连接 (rclone lsd gdrive:)..."
    docker run --rm \
      --net=host \
      -v "$RCLONE_DIR:/root/.config/rclone" \
      --entrypoint rclone \
      creativeprojects/resticprofile:latest \
      lsd gdrive:
    exit 0
    ;;
  4)
    echo "已取消。"
    exit 0
    ;;
  *)
    echo "无效选项。"
    exit 1
    ;;
esac

echo ""
if [ -f "$RCLONE_DIR/rclone.conf" ]; then
  echo "=========================================================="
  echo "✅ Google Drive 授权成功！rclone.conf 已生成："
  echo "   $RCLONE_DIR/rclone.conf"
  echo ""
  echo "测试连接中..."
  docker run --rm \
    --net=host \
    -v "$RCLONE_DIR:/root/.config/rclone" \
    --entrypoint rclone \
    creativeprojects/resticprofile:latest \
    lsd gdrive: || true
  echo ""
  echo "后续步骤："
  echo "  1. 运行 ./backup-now.sh 执行一次立即备份验证"
  echo "  2. 运行 docker compose up -d 启动后台每30分钟定时备份"
  echo "=========================================================="
else
  echo "⚠️ 未检测到 rclone.conf，请检查刚才的授权步骤。"
fi
