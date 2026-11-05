#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ $# -eq 0 ]; then
  echo "用法: $0 <command> [args...]"
  echo ""
  echo "常用示例:"
  echo "  $0 snapshots                        # 查看所有备份快照"
  echo "  $0 ls latest                        # 查看最新快照中的文件清单"
  echo "  $0 diff <snap_id_1> <snap_id_2>     # 对比两个快照之间的差异"
  echo "  $0 check                            # 检查仓库完整性"
  echo "  $0 status                           # 查看定时计划任务状态"
  echo "  $0 restore latest --target /tmp/res # 恢复最新快照到指定目录"
  echo "  $0 prune                            # 清理过期的无用数据块"
  echo ""
  exit 0
fi

if [ ! -f "$SCRIPT_DIR/rclone/rclone.conf" ]; then
  echo "❌ 错误: 未找到 $SCRIPT_DIR/rclone/rclone.conf"
  echo "请先运行 ./rclone-login.sh 完成 Google Drive 的 OAuth 登录授权。"
  exit 1
fi

# 对于纯只读查询类命令 (snapshots, ls, diff, cat)，自动附加 --no-lock
# 避免向 Google Drive 创建和删除锁文件，消除 30 秒以上的 API 限流休眠排队
EXTRA_ARGS=()
case "$1" in
  snapshots|ls|diff|cat)
    if [[ ! " $* " =~ " --no-lock " ]]; then
      EXTRA_ARGS=("--no-lock")
    fi
    ;;
esac

echo "==> 执行底层命令: resticprofile --verbose -c /etc/resticprofile/profiles.yaml $@ ${EXTRA_ARGS[*]}"

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
  "$@" \
  "${EXTRA_ARGS[@]}"
