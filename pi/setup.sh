#!/usr/bin/env bash
# setup.sh — 安装 pi 配置的软链接
# 用法：在 dotfiles 仓库根目录（或任意位置）执行 ./pi/setup.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

AGENT_DIR="${HOME}/.pi/agent"
LOCAL_BIN="${HOME}/.local/bin"

# ---------- 依赖检测与原生 pi 自动安装 ----------
# 与 wrapper bin/pi 保持一致的查找链；找不到原生 pi 时自动安装而不是只提醒。
PI_PACKAGE="@earendil-works/pi-coding-agent"
nvm_dir="${NVM_DIR:-$HOME/.nvm}"

# node：PATH → nvm fallback（与 wrapper 一致）；ls glob 不匹配时 pipefail 会非零，需 || true 兑底
NODE_BIN="$(command -v node 2>/dev/null || true)"
if [ -z "$NODE_BIN" ]; then
    NODE_BIN="$(ls -t "$nvm_dir"/versions/node/*/bin/node 2>/dev/null | head -1 || true)"
    [ -x "$NODE_BIN" ] && export PATH="$(dirname "$NODE_BIN"):$PATH"
fi

# npm：PATH → node 自带 npm-cli.js（distro node 常见：npm 不在 PATH 但随 node 分发）
resolve_npm() {
    NPM_BIN="$(command -v npm 2>/dev/null || true)"
    NPM_CLI=""
    if [ -z "$NPM_BIN" ] && [ -n "$NODE_BIN" ] && [ -f "${NODE_BIN%/node}/../lib/node_modules/npm/bin/npm-cli.js" ]; then
        NPM_CLI="${NODE_BIN%/node}/../lib/node_modules/npm/bin/npm-cli.js"
    fi
}
resolve_npm
has_npm() { [ -n "$NPM_BIN" ] || { [ -n "$NPM_CLI" ] && [ -n "$NODE_BIN" ]; }; }
npm_run() {
    if [ -n "$NPM_BIN" ]; then "$NPM_BIN" "$@"; else "$NODE_BIN" "$NPM_CLI" "$@"; fi
}

# 原生 pi 查找链（幂等：任意命中即短路）：
#   1. node 旁边的 bin 软链（npm 维护，首选入口）
#   2. PATH 上任何不是本仓库 wrapper 的 pi（自定义 prefix 等）
#   3. 官方 installer 托管入口 ~/.pi/agent/bin/pi（installer 刻意避开
#      ~/.local/bin，因为那里是 wrapper）
#   4. 本脚本旧版自动安装的用户级 prefix ~/.pi/npm-global
#   5. nvm 最新版本（shell 未加载 nvm 或默认 node 版本不同的情况）
agent_dir="${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}"
wrapper_real="$(readlink -f -- "$SCRIPT_DIR/bin/pi" 2>/dev/null || printf '%s' "$SCRIPT_DIR/bin/pi")"
locate_pi() {
    real_pi=""
    if [ -n "$NODE_BIN" ]; then
        cand="${NODE_BIN%/node}/pi"
        [ -x "$cand" ] && real_pi="$cand" && return 0
    fi
    while IFS= read -r cand; do
        [ -x "$cand" ] || continue
        cand_real="$(readlink -f -- "$cand" 2>/dev/null || printf '%s' "$cand")"
        if [ "$cand_real" != "$wrapper_real" ]; then real_pi="$cand"; return 0; fi
    done < <(type -ap pi)
    cand="$agent_dir/bin/pi"
    [ -x "$cand" ] && real_pi="$cand" && return 0
    cand="$HOME/.pi/npm-global/bin/pi"
    [ -x "$cand" ] && real_pi="$cand" && return 0
    cand="$(ls -t "$nvm_dir"/versions/node/*/bin/pi 2>/dev/null | head -1 || true)"
    [ -x "$cand" ] && real_pi="$cand" && return 0
    # 自定义全局 prefix：直接问 npm 装在哪（幂等复查用）
    if has_npm; then
        cand="$(npm_run prefix -g 2>/dev/null || true)/bin/pi"
        [ -x "$cand" ] && real_pi="$cand" && return 0
    fi
    return 1
}
locate_pi || true

# 缺失 → 自动安装（官方方式）
if [ -z "$real_pi" ]; then
    if [ -n "$NODE_BIN" ]; then
        if ! has_npm; then
            echo "✗ 有 node 但找不到 npm（PATH 与 node 自带 npm-cli.js 均无），无法自动安装 pi"
            echo "  手动安装：npm install -g --ignore-scripts $PI_PACKAGE"
            exit 1
        fi
        echo "未找到原生 pi，通过 npm 全局安装（官方方式）..."
        if npm_run install -g --ignore-scripts "$PI_PACKAGE"; then
            # npm 全局 prefix 可能不在 PATH 上，先问 npm 装到哪了，再做全量复查
            cand="$(npm_run prefix -g 2>/dev/null || true)/bin/pi"
            if [ -x "$cand" ]; then real_pi="$cand"; else locate_pi || true; fi
        fi
        # 全局安装失败（如 distro node 无写权限）→ 用户级 prefix 重试。
        # 刻意不用 ~/.local/bin：那是 wrapper 的家，npm 会用 bin 软链覆盖它。
        if [ -z "$real_pi" ]; then
            pi_user_prefix="$HOME/.pi/npm-global"
            echo "npm 全局安装未成功，重试到用户级 prefix $pi_user_prefix ..."
            if npm_run install -g --prefix "$pi_user_prefix" --ignore-scripts "$PI_PACKAGE"; then
                real_pi="$pi_user_prefix/bin/pi"
                export PATH="$pi_user_prefix/bin:$PATH"
            fi
        fi
    else
        echo "未找到 node 与原生 pi，运行官方 installer（会一并装好 node）..."
        if ! curl -fsSL https://pi.dev/install.sh | sh; then
            echo "  ℹ 官方 installer 未成功（网络或非交互环境问题），可稍后手动执行"
        fi
        # installer 可能带回了 node，重新探测
        NODE_BIN="$(command -v node 2>/dev/null || true)"
        resolve_npm
        locate_pi || true
    fi
fi

if [ -z "$real_pi" ]; then
    echo "✗ 自动安装失败：未能获得原生 pi CLI"
    echo "  手动安装：npm install -g --ignore-scripts $PI_PACKAGE"
    echo "  或官方 installer：curl -fsSL https://pi.dev/install.sh | sh"
    exit 1
fi
echo "✓ 原生 pi：$real_pi（node: ${NODE_BIN:-无}）"

# ---------- 软链接 ----------
# ln_checked <repo文件> <目标路径>
# 目标已是正确软链 → 跳过；目标已存在且是真文件 → 备份为 *.setup.bak 再链接
ln_checked() {
    local src="$1" dst="$2"
    if [ -L "$dst" ] && [ "$(readlink -f "$dst")" = "$(readlink -f "$src")" ]; then
        echo "  = $dst （已是正确软链）"
        return
    fi
    if [ -e "$dst" ] && [ ! -L "$dst" ]; then
        local bak="${dst}.setup.bak"
        echo "  ~ $dst 已存在，备份到 $bak"
        mv "$dst" "$bak"
    fi
    mkdir -p "$(dirname "$dst")"
    ln -sf "$src" "$dst"
    echo "  + $dst -> $src"
}

echo "设置软链接："
mkdir -p "$AGENT_DIR/extensions" "$LOCAL_BIN"
ln_checked "$SCRIPT_DIR/settings.json"          "$AGENT_DIR/settings.json"
ln_checked "$SCRIPT_DIR/models.json"            "$AGENT_DIR/models.json"
ln_checked "$SCRIPT_DIR/extensions/error-classifier.ts" "$AGENT_DIR/extensions/error-classifier.ts"
ln_checked "$SCRIPT_DIR/fix-host-peer-deps.mjs"  "$AGENT_DIR/fix-host-peer-deps.mjs"
ln_checked "$SCRIPT_DIR/bin/pi"                 "$LOCAL_BIN/pi"

# ---------- 按 settings.json 安装缺失的扩展包 ----------
# pi install 不读 settings.json，需逐个指定来源；已安装的跳过，重复执行安全。
echo "检查扩展包："
while read -r src; do
    [ -z "$src" ] && continue
    case "$src" in
        npm:*)
            dst="$AGENT_DIR/npm/node_modules/${src#npm:}" ;;
        git:*)
            dst="$AGENT_DIR/git/${src#git:}" ;;
        *)
            dst="" ;;
    esac
    if [ -n "$dst" ] && [ -e "$dst" ]; then
        echo "  = $src （已安装）"
    else
        echo "  + 安装 $src"
        if "$real_pi" install "$src" --approve; then
            echo "  ✓ $src"
        else
            echo "  ✗ $src 安装失败，可稍后手动：pi install $src"
        fi
    fi
done < <(grep -oE '"(npm|git):[^"]+"' "$SCRIPT_DIR/settings.json" | tr -d '"')

# ---------- qmd（pi-memory 的 memory_search 依赖，pi 不会自动装） ----------
if command -v qmd >/dev/null 2>&1; then
    echo "  = qmd （已安装）"
else
    echo "  + 安装 qmd（pi-memory 的 memory_search 需要）"
    if has_npm && npm_run install -g @tobilu/qmd; then
        if qmd collection add "$AGENT_DIR/memory" --name pi-memory && qmd embed; then
            echo "  ✓ qmd 集合已建并生成索引"
        else
            echo "  ℹ 集合/索引创建失败也没关系：下次 pi 启动时 pi-memory 会自动补建"
        fi
    else
        echo "  ✗ qmd 安装失败，可手动：npm install -g @tobilu/qmd"
    fi
fi

echo
echo "完成。首次使用：在 pi 里运行 /login 配置 OAuth 凭证，或用 pi auth check 检查 API key。"