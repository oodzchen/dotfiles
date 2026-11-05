#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SNAPSHOT="${1:-latest}"
TARGET_DIR="${2:-$SCRIPT_DIR/restored}"

if [ ! -f "$SCRIPT_DIR/key" ]; then
  echo "❌ 错误: 未找到仓库加密密钥 $SCRIPT_DIR/key"
  echo "在还原前，请先将备份的 key 密钥文件放入当前目录。"
  exit 1
fi

if [ ! -f "$SCRIPT_DIR/rclone/rclone.conf" ]; then
  echo "❌ 错误: 未找到 $SCRIPT_DIR/rclone/rclone.conf"
  echo "请先运行 ./rclone-login.sh 完成 Google Drive 授权。"
  exit 1
fi

mkdir -p "$TARGET_DIR"
TARGET_DIR_ABS="$(cd "$TARGET_DIR" && pwd)"

echo "=========================================================="
echo "          从 Google Drive 恢复备份快照"
echo "          快照 ID:  $SNAPSHOT"
echo "          临时目录: $TARGET_DIR_ABS"
echo "=========================================================="

echo "==> 执行底层还原命令..."
docker run --rm -it \
  --net=host \
  -v "$SCRIPT_DIR/profiles.yaml:/etc/resticprofile/profiles.yaml:ro" \
  -v "$SCRIPT_DIR/key:/etc/resticprofile/key:ro" \
  -v "$SCRIPT_DIR/rclone:/etc/resticprofile/rclone" \
  -v "$SCRIPT_DIR/cache:/root/.cache/restic" \
  -v /etc/localtime:/etc/localtime:ro \
  -v "$TARGET_DIR_ABS:/restore:rw" \
  creativeprojects/resticprofile:latest \
  --verbose \
  -c /etc/resticprofile/profiles.yaml \
  restore "$SNAPSHOT" --target /restore

echo ""
echo "=========================================================="
echo "🎉 还原完成！所有配置文件已解包至: $TARGET_DIR_ABS/data"
echo ""
echo "如需将配置同步生效到当前系统的家目录 ($HOME)，可执行："
echo "  # 1. 试探性安全合并（已有同名文件不覆盖）："
echo "  cp -rn \"$TARGET_DIR_ABS/data/.\" ~/"
echo ""
echo "  # 2. 或完全同步覆盖至当前家目录："
echo "  rsync -av \"$TARGET_DIR_ABS/data/\" ~/"
echo ""
echo "确认生效后可删除临时目录: rm -rf \"$TARGET_DIR_ABS\""
echo "=========================================================="
