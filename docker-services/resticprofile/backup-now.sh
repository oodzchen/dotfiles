#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ ! -f "$SCRIPT_DIR/rclone/rclone.conf" ]; then
  echo "❌ 错误: 未找到 $SCRIPT_DIR/rclone/rclone.conf"
  echo "请先运行 ./rclone-login.sh 完成 Google Drive 的 OAuth 登录授权。"
  exit 1
fi

echo "=========================================================="
echo "          手动触发即时备份 (Profile: default)"
echo "=========================================================="
echo "==> 执行底层命令: resticprofile --verbose -c /etc/resticprofile/profiles.yaml backup"
docker run --rm -it \
  --net=host \
  -v "$SCRIPT_DIR/profiles.yaml:/etc/resticprofile/profiles.yaml:ro" \
  -v "$SCRIPT_DIR/key:/etc/resticprofile/key:ro" \
  -v "$SCRIPT_DIR/rclone:/etc/resticprofile/rclone" \
  -v "$SCRIPT_DIR/cache:/root/.cache/restic" \
  -v /etc/localtime:/etc/localtime:ro \
  -v "${HOME}:/data:ro" \
  creativeprojects/resticprofile:latest \
  --verbose \
  -c /etc/resticprofile/profiles.yaml \
  backup
