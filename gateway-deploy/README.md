# Sub2API Gateway Deploy Kit

这是一套给小规模长期运营用的 Sub2API 部署包，目标是：

- 本地先用 `http://localhost:18080` 看到完整前台和后台。
- 上 VPS 后用 Docker Compose 一键部署。
- 用户开放注册、查看自己的 key 和额度。
- 支付系统不接入，你在后台手动给用户加余额或额度。
- 默认只开放 Caddy 的 HTTP/HTTPS 入口，PostgreSQL、Redis、Sub2API 内部端口不暴露公网。
- 默认启用上游 URL 白名单，避免网关被误配置成任意转发器。

## 本地预览

Windows PowerShell：

```powershell
cd D:\Document\New project\gateway-deploy
.\scripts\init-secrets.ps1
.\scripts\verify.ps1
```

打开：

```text
http://localhost:18080
```

Linux / VPS：

```bash
cd gateway-deploy
chmod +x scripts/*.sh
./scripts/init-secrets.sh
./scripts/verify.sh
```

## 正式部署

1. 买 VPS，推荐 Ubuntu 22.04/24.04，2C4G 起步。
2. 安装 Docker 和 Docker Compose。
3. 把整个 `gateway-deploy` 目录上传到服务器。
4. 运行 `./scripts/init-secrets.sh` 生成 `.env`。
5. 编辑 `.env`：

```dotenv
SITE_ADDRESS=api.example.com
PUBLIC_HTTP_PORT=80
PUBLIC_HTTPS_PORT=443
APP_BASE_URL=https://api.example.com
CORS_ALLOWED_ORIGINS=https://api.example.com
ADMIN_EMAIL=你的管理员邮箱
SECURITY_URL_ALLOWLIST_UPSTREAM_HOSTS=ai.nexahub.one
```

6. 启动：

```bash
docker compose up -d
docker compose ps
```

7. 访问：

```text
https://api.example.com
https://api.example.com/v1/models
```

Cloudflare 使用建议：

- 第一次签发 HTTPS 证书时，域名 DNS 先用 DNS only。
- Caddy 证书正常后，再打开 Cloudflare 代理小云朵。
- Cloudflare SSL/TLS 模式选 Full 或 Full (strict)。

## 运营流程

你的人工充值模式是：

1. 用户访问站点注册。
2. 用户把注册邮箱发给你。
3. 你确认转账。
4. 你登录后台找到该用户。
5. 给用户增加余额，或给他的 API Key 设置额度。
6. 用户在自己的密钥页面查看/创建 key。
7. 用户调用：

```text
Base URL: https://api.example.com/v1
API Key: 用户自己的 key
```

## 上游配置

后台添加 OpenAI-compatible 上游：

```text
Platform: openai
Type: apikey
Base URL: https://ai.nexahub.one/v1
API Key: 你的上游 key
```

然后同步模型，创建分组，把账号绑定到分组。

## 安全基线

已经在部署包里处理的部分：

- 数据库和 Redis 不开放宿主机端口。
- Redis 强制密码。
- JWT、TOTP、数据库密码、Redis 密码由脚本生成。
- Caddy 统一入口，Sub2API 只在 Docker 内网暴露。
- Caddy 关闭公开支付路径。
- 上游 URL allowlist 默认启用。
- Caddy 设置常见安全响应头。
- 请求体大小有限制。
- `.env`、数据目录、备份目录默认被 `.gitignore` 忽略。

你上线前还需要做：

- 改管理员邮箱和密码。
- 管理员开启 2FA。
- 服务器只开放 80/443/SSH。
- SSH 禁用密码登录，使用密钥登录。
- 后台管理最好套 Cloudflare Zero Trust。
- 每个用户单独发 key，不要共用 key。
- 给每个用户/key 设置额度和频率限制。
- 定期运行备份脚本并把备份下载到本地。

## 常用命令

```bash
docker compose up -d
docker compose ps
docker compose logs -f sub2api
docker compose logs -f caddy
docker compose pull
docker compose up -d
docker compose down
```

备份：

```bash
./scripts/backup.sh
```

停止：

```bash
docker compose down
```

彻底删除数据前请确认已经备份：

```bash
docker compose down
rm -rf data postgres_data redis_data caddy_data caddy_config
```
