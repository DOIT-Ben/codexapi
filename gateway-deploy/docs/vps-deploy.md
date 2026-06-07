# VPS Deployment Notes

推荐规格：

- 2 vCPU / 4 GB RAM / 50 GB SSD：适合 20 人小规模长期使用。
- 4 vCPU / 8 GB RAM：更稳，适合更多流式请求和日志。

Ubuntu 初始化：

```bash
sudo apt update
sudo apt install -y ca-certificates curl gnupg ufw
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker "$USER"
newgrp docker
```

防火墙：

```bash
sudo ufw allow OpenSSH
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable
sudo ufw status
```

部署：

```bash
cd gateway-deploy
chmod +x scripts/*.sh
./scripts/init-secrets.sh
nano .env
docker compose up -d
docker compose ps
```

更新：

```bash
./scripts/backup.sh
docker compose pull
docker compose up -d
docker compose ps
```
