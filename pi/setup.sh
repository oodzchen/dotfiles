#!/usr/bin/env bash
# setup.sh — 安装 pi 配置的软链接
# 用法：在 dotfiles 仓库根目录（或任意位置）执行 ./pi/setup.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

AGENT_DIR="${HOME}/.pi/agent"
LOCAL_BIN="${HOME}/.local/bin"

# ---------- 依赖检测 ----------
missing=()
warn=()

if ! command -v python3 >/dev/null 2>&1; then
    missing+=("python3  （wrapper 启动时运行 fix-host-peer-deps.py 需要）")
fi
if ! command -v node >/dev/null 2>&1; then
    warn+=("node 不在当前 PATH。wrapper 有 nvm fallback（$HOME/.nvm/versions/node/*/bin），")
    warn+=("  若也未安装 nvm + pi，pi 将无法启动。建议：curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash && nvm install --lts")
fi
if ! command -v npm >/dev/null 2>&1 && ! ls "$HOME"/.nvm/versions/node/*/bin/npm >/dev/null 2>&1; then
    missing+=("npm  （用于 npm install -g @earendil-works/pi-coding-agent）")
fi

# 原生 pi（npm 全局安装的 CLI）：PATH 或 nvm 目录里找
real_pi="$(command -v pi 2>/dev/null || true)"
if [ -z "$real_pi" ] || [ "$(readlink -f "$real_pi")" = "$(readlink -f "${SCRIPT_DIR}/bin/pi" 2>/dev/null)" ]; then
    # PATH 里没有（或只有我们的 wrapper），再探 nvm
    real_pi="$(ls -t "$HOME"/.nvm/versions/node/*/bin/pi 2>/dev/null | head -1 || true)"
fi
if [ -z "$real_pi" ]; then
    missing+=("原生 pi CLI  （npm install -g @earendil-works/pi-coding-agent）")
fi

if [ ${#missing[@]} -gt 0 ]; then
    echo "缺少以下依赖，暂不设置软链接："
    for m in "${missing[@]}"; do echo "  ✗ $m"; done
    echo "装好后重新运行本脚本即可。"
    exit 1
fi
for w in "${warn[@]:-}"; do [ -n "$w" ] && echo "⚠ $w"; done

echo "✓ 依赖检查通过（pi: ${real_pi}, python3: $(command -v python3)）"

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
ln_checked "$SCRIPT_DIR/fix-host-peer-deps.py"  "$AGENT_DIR/fix-host-peer-deps.py"
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
        if pi install "$src" --approve; then
            echo "  ✓ $src"
        else
            echo "  ✗ $src 安装失败，可稍后手动：pi install $src"
        fi
    fi
done < <(python3 -c 'import json,sys; [print(p) for p in json.load(open(sys.argv[1]))["packages"] if isinstance(p,str)]' "$SCRIPT_DIR/settings.json")

# ---------- qmd（pi-memory 的 memory_search 依赖，pi 不会自动装） ----------
if command -v qmd >/dev/null 2>&1; then
    echo "  = qmd （已安装）"
else
    echo "  + 安装 qmd（pi-memory 的 memory_search 需要）"
    if npm install -g @tobilu/qmd; then
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