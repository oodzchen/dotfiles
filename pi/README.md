# pi 配置

[coding agent pi](https://github.com/earendil-works/pi-coding-agent) 的用户级配置（`~/.pi/agent/`）。

## 内容

| 文件 | 软链到 |
|---|---|
| `settings.json` | `~/.pi/agent/settings.json` — 包列表、默认模型/主题 |
| `models.json` | `~/.pi/agent/models.json` — 自定义模型定义 |
| `extensions/error-classifier.ts` | `~/.pi/agent/extensions/` — 自定义扩展 |
| `fix-host-peer-deps.py` | `~/.pi/agent/` — peer-deps 自动补丁脚本 |
| `bin/pi` | `~/.local/bin/pi` — 启动 wrapper（补丁 + nvm fallback + 禁用退出摘要） |

## 安装（新机器）

```bash
./pi/setup.sh      # 检测依赖 → 建软链 → 安装缺失的扩展包 → 提示 pi login
```

脚本幂等，可重复执行：已是正确软链会跳过；目标位置已有真文件会先备份为
`*.setup.bak` 再链接；已安装的扩展包跳过；缺依赖时报错退出、不做任何改动。
注意：软链生效后，对 `~/.pi/agent/settings.json` 的重定向写入
（如 `echo x > ~/.pi/agent/settings.json`）会穿透软链覆盖仓库文件。
用 `pi` 本身的配置命令（如 `pi install`）没有这个问题，它们会写入真实文件。

## 手动安装（不跑脚本）

```bash
ln -sf "$(pwd)/pi/settings.json" ~/.pi/agent/settings.json
ln -sf "$(pwd)/pi/models.json" ~/.pi/agent/models.json
mkdir -p ~/.pi/agent/extensions ~/.local/bin
ln -sf "$(pwd)/pi/extensions/error-classifier.ts" ~/.pi/agent/extensions/error-classifier.ts
ln -sf "$(pwd)/pi/fix-host-peer-deps.py" ~/.pi/agent/fix-host-peer-deps.py
ln -sf "$(pwd)/pi/bin/pi" ~/.local/bin/pi
```

settings.json 里的 packages 声明 + `./pi/setup.sh` 会自动安装缺失的包，
无需备份 `npm/`、`git/` 下的包本体。