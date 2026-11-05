# resticprofile 自动备份服务 (Docker + rclone + Google Drive)

基于 [resticprofile 官方 Docker 规范](https://creativeprojects.github.io/resticprofile/installation/docker/index.html) 与 [schedule-in-docker](https://github.com/creativeprojects/resticprofile/tree/master/contrib/schedule-in-docker) 方案搭建。

## 目录结构

```
~/docker-services/resticprofile/
├── docker-compose.yml       # Docker Compose 服务配置（基于 host 网络与 crond 常驻）
├── profiles.yaml            # resticprofile 核心配置（白名单备份源、通用排除项、定时策略、保留周期）
├── key                      # 仓库对称加密密钥（32 字符高熵值，请务必存入密码管理器备份！）
├── rclone/                  # rclone 凭证目录（内含 rclone.conf）
├── cache/                   # 本地 restic 索引缓存（加速增量对比，避免重复拉取云端索引）
├── rclone-login.sh          # Google Drive OAuth 登录与授权向导
├── backup-now.sh            # 手动执行一次即时备份（开启实时详细输出）
├── restore.sh               # 一键快照还原脚本（自动解包至本地临时目录）
├── restic-cli.sh            # 快照查看、文件恢复与完整性校验便捷工具（自动优化只读命令）
├── .gitignore               # 针对 Git/dotfiles 仓库的凭据与缓存忽略规则
└── README.md                # 本说明文档
```

## 路径通用化设计（换机换用户名零成本迁移）

容器采用通用路径映射：
- **宿主机端**：通过 `${HOME}:/data:ro` 将当前用户的家目录动态挂载入容器。
- **配置与快照端**：所有备份路径均以 `/data/...` 记录（如 `/data/.config/...`、`/data/.bashrc`）。
- **换机换用户名**：无论新主机的用户名是 `kholin`、`alice` 还是 `ubuntu`，配置文件完全无需修改，开箱即用。

---

## 备份到 Dotfiles 仓库规范

若您希望将本套备份配置纳入个人的 `dotfiles` 仓库进行版本管理：

### 1. 允许公开/提交到 Git 的文件：
* `docker-compose.yml`
* `profiles.yaml`
* `backup-now.sh`
* `restore.sh`
* `restic-cli.sh`
* `rclone-login.sh`
* `README.md`
* `.gitignore`

### 2. 绝对不能明文提交到公共 Git 的敏感文件：
* `key`：**仓库加密密钥**。如果丢失，Google Drive 上的备份将永远无法解密！请存入 1Password / Bitwarden / KeePass 密码管理器备份。
* `rclone/rclone.conf`：**Google Drive OAuth 登录 Token**。包含敏感身份认证令牌。（项目内已配置 `.gitignore` 自动忽略）。

---

## 换机与数据还原指南 (3 步极速还原)

当您换了新电脑或重装系统后，还原非常简单：

### 步骤 1：准备配置与密钥
1. 将本目录从 dotfiles 仓库拉取到新机器（如 `~/docker-services/resticprofile`）。
2. 从密码管理器中取出 `key`，保存到 `~/docker-services/resticprofile/key` 并赋予 `0600` 权限：
   ```bash
   chmod 600 key
   ```

### 步骤 2：授权 Google Drive
运行登录向导完成浏览器一次性授权：
```bash
./rclone-login.sh
```

### 步骤 3：一键还原配置
运行还原脚本，默认拉取最新快照：
```bash
./restore.sh
```
所有配置文件将自动解压至本地 `./restored/data/` 目录。

根据需要同步到当前新系统的家目录：
```bash
# 试探性合并（不覆盖已有文件）：
cp -rn ./restored/data/. ~/

# 或直接覆盖同步：
rsync -av ./restored/data/ ~/

# 确认生效后清理临时目录：
rm -rf ./restored
```

---

## 常用命令一览

```bash
cd ~/docker-services/resticprofile

# 查看当前运行中的所有快照 (默认 --verbose 详细模式 + 极速免锁)
./restic-cli.sh snapshots

# 查看最新快照包含的文件清单
./restic-cli.sh ls latest

# 对比两个快照之间的差异
./restic-cli.sh diff <snap_id_1> <snap_id_2>

# 检查云端仓库数据完整性
./restic-cli.sh check

# 手动立即触发一次增量备份
./backup-now.sh

# 查看后台常驻定时备份容器日志 (每30分钟自动触发一次)
docker compose logs -f
```
