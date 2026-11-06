# pi 配置

[coding agent pi](https://github.com/earendil-works/pi-coding-agent) 的用户级配置（`~/.pi/agent/`）。

## 内容

| 文件 | 软链到 |
|---|---|
| `settings.json` | `~/.pi/agent/settings.json` — 包列表、默认模型/主题 |
| `models.json` | `~/.pi/agent/models.json` — 自定义模型定义 |
| `web-search.json` | `~/.pi/agent/web-search.json` — web 工具 SSRF 白名单（fake-IP） |
| `extensions/error-classifier.ts` | `~/.pi/agent/extensions/` — 自定义扩展 |
| `extensions/clear-alias.ts` | `~/.pi/agent/extensions/` — 注册 `/clear` 别名以开启新会话（等价于 `/new`） |
| `extensions/prefer-rg.ts` | `~/.pi/agent/extensions/` — 优先 ripgrep（提示词 + 拦截递归 grep） |
| `extensions/hide-commands.ts` | `~/.pi/agent/extensions/` — 从 `/` 补全菜单隐藏内置命令（默认隐藏 `/clone` 与 `/new`，配置 `~/.pi/agent/hide-commands.json`） |
| `extensions/remember-last-model.ts` | `~/.pi/agent/extensions/` — 自动持久化上次选择的模型与思考级别（存入 `last-model.json`） |
| `fix-host-peer-deps.mjs` | `~/.pi/agent/` — peer-deps 自动补丁脚本 |
| `bin/pi` | `~/.local/bin/pi` — 启动 wrapper（nvm fallback + 禁用退出摘要） |

## 斜杠命令定制：/clear 取代 /new、隐藏 /clone

通过纯扩展（Extension API）解耦实现，不修改 Pi 安装目录下的打包文件，升级免维护：

- `extensions/clear-alias.ts`：注册 `/clear` 命令，执行 `ctx.newSession()` 开新会话。
- `extensions/hide-commands.ts`：通过包装 autocomplete provider，默认从斜杠补全列表中过滤掉 `/clone` 和 `/new`。
  - 用户输入 `/` 时只展示推荐的 `/clear`，不会看到多余的 `/new` 与 `/clone`。
  - 完整手输 `/new` 或 `/clone` 依然能正常触发 Pi 的原生处理。
  - 支持交互式增删隐藏项：`/hide-commands [status|on|off|add <name>|remove <name>|reset]`。

## 安装（新机器）

```bash
./pi/setup.sh      # 检测依赖 → 建软链 → 安装缺失的扩展包
pi                 # 首次使用：在 pi 里 /login 配置 OAuth，或 pi auth check 检查凭证
```

脚本幂等，可重复执行：已是正确软链会跳过；目标位置已有真文件会先备份为
`*.setup.bak` 再链接；已安装的扩展包跳过；缺依赖时报错退出、不做任何改动。
同时检查 qmd（pi-memory 的 memory_search 依赖，缺失时 `npm install -g @tobilu/qmd`
并建集合/索引）。
注意：软链生效后，对 `~/.pi/agent/settings.json` 的重定向写入
（如 `echo x > ~/.pi/agent/settings.json`）会穿透软链覆盖仓库文件。
用 `pi` 本身的配置命令（如 `pi install`）没有这个问题，它们会写入真实文件。

## 手动安装（不跑脚本）

```bash
ln -sf "$(pwd)/pi/settings.json" ~/.pi/agent/settings.json
ln -sf "$(pwd)/pi/models.json" ~/.pi/agent/models.json
ln -sf "$(pwd)/pi/web-search.json" ~/.pi/agent/web-search.json
mkdir -p ~/.pi/agent/extensions ~/.local/bin
ln -sf "$(pwd)/pi/extensions/error-classifier.ts" ~/.pi/agent/extensions/error-classifier.ts
ln -sf "$(pwd)/pi/extensions/clear-alias.ts" ~/.pi/agent/extensions/clear-alias.ts
ln -sf "$(pwd)/pi/extensions/prefer-rg.ts" ~/.pi/agent/extensions/prefer-rg.ts
ln -sf "$(pwd)/pi/extensions/hide-commands.ts" ~/.pi/agent/extensions/hide-commands.ts
ln -sf "$(pwd)/pi/extensions/remember-last-model.ts" ~/.pi/agent/extensions/remember-last-model.ts
ln -sf "$(pwd)/pi/fix-host-peer-deps.mjs" ~/.pi/agent/fix-host-peer-deps.mjs
ln -sf "$(pwd)/pi/bin/pi" ~/.local/bin/pi
```

settings.json 里的 packages 声明 + `./pi/setup.sh` 会自动安装缺失的包，
无需备份 `npm/`、`git/` 下的包本体。
