# Admin Access

本部署包默认不让公网直接访问管理员后台：

- `/admin*`
- `/api/v1/admin/*`

公网访问这些路径会返回 404。这样即使后台密码泄露、被爆破或被扫描到，攻击面也会小很多。

## 本地开发

本机访问不受影响：

```text
http://localhost:18080/admin
```

## VPS 生产环境

推荐用 SSH 隧道访问后台：

```bash
ssh -L 18080:127.0.0.1:80 root@your-vps-ip
```

然后在自己电脑打开：

```text
http://localhost:18080/admin
```

用户仍然可以正常访问你的公网域名和 `/v1/*` API。

## 如果你要用 Cloudflare Zero Trust

先保持默认拦截。等 Cloudflare Access 配好后，再按你的真实部署方式调整 Caddy 的 `@public_admin` 规则，只允许 Cloudflare/内网/指定 IP 进入后台。

不要在源站未锁定的情况下信任 `CF-Connecting-IP` 或 `X-Forwarded-For`。
