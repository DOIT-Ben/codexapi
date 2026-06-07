# Security Checklist

上线前逐项确认：

- [ ] `.env` 不提交到 Git，不放到网站目录。
- [ ] `ADMIN_PASSWORD` 是强密码，并且管理员登录后开启 2FA。
- [ ] `JWT_SECRET`、`TOTP_ENCRYPTION_KEY`、数据库密码、Redis 密码已生成强随机值。
- [ ] `SECURITY_URL_ALLOWLIST_ENABLED=true`。
- [ ] `SECURITY_URL_ALLOWLIST_UPSTREAM_HOSTS` 只包含可信上游域名。
- [ ] `SECURITY_URL_ALLOWLIST_ALLOW_PRIVATE_HOSTS=false`。
- [ ] `SECURITY_TRUST_FORWARDED_IP_FOR_API_KEY_ACL=false`，除非源站已经只允许 Cloudflare/可信反代访问。
- [ ] PostgreSQL 没有映射公网端口。
- [ ] Redis 没有映射公网端口，并且设置了密码。
- [ ] Sub2API 后端端口没有直接暴露公网，只允许 Caddy 反代访问。
- [ ] VPS 防火墙只开放 SSH、80、443。
- [ ] SSH 使用密钥登录，关闭密码登录。
- [ ] Cloudflare SSL/TLS 使用 Full 或 Full (strict)。
- [ ] 如果使用 Cloudflare，源站防火墙只允许 Cloudflare IP 访问 80/443。
- [ ] 支付系统未配置时，公开支付路径由 Caddy 返回 404。
- [ ] 管理员后台公网访问返回 404；日常管理通过 SSH 隧道、内网、Cloudflare Zero Trust 或 IP 白名单访问。
- [ ] 每个用户单独 API Key，不共用 key。
- [ ] 每个用户或 key 设置额度和频率限制。
- [ ] 定期备份 PostgreSQL，并把备份下载到本地。
- [ ] 更新镜像前先备份数据库，并尽量固定 `SUB2API_IMAGE` 到明确版本或 digest。

高风险提醒：

- 不要让公网直接访问 PostgreSQL、Redis、Docker API 或 Sub2API 的内部端口。
- 不要在未锁源站的情况下信任 `CF-Connecting-IP`、`X-Forwarded-For` 这类客户端可伪造的请求头。
- 不要把管理员后台只靠一个密码裸露在公网长期运行；本部署包默认拦截公网访问 `/admin*` 和 `/api/v1/admin/*`。
