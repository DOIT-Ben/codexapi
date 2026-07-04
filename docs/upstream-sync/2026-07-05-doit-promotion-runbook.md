# Doit API Staging Promotion Runbook

## 目标

将已验证的 `workbench\upstream-sync\sub2api-doit-0.1.144` 提升为当前 `sub2api` 源码，同时保留当前本地运行配置和数据。

## 默认边界

脚本默认只 dry-run，不会替换任何文件。真正替换必须显式传入 `-Execute`。

保留内容：

- `sub2api\deploy\.env`
- `sub2api\deploy\config.yaml`
- `sub2api\deploy\data`
- `sub2api\deploy\postgres_data`
- `sub2api\deploy\redis_data`
- `sub2api\deploy\backups`
- `sub2api\deploy\caddy_data`
- `sub2api\deploy\caddy_config`

不保留内容：

- 旧版官方源码文件
- 旧版前端源码文件
- 旧版后端源码文件
- 旧版部署模板文件

## Dry-run

前置条件：Docker Desktop 必须正在运行。若 `docker ps` 报 Docker API 不可用，先启动 Docker Desktop，再重新运行验证和预检。

确认 staging 自身验证通过：

```powershell
.\scripts\sub2api-verify-staging.ps1 -CheckHttp
```

查看 staging 容器状态：

```powershell
.\scripts\sub2api-staging-compose.ps1 status
.\scripts\sub2api-staging-compose.ps1 health
```

`sub2api-staging-compose.ps1` 默认从 `customizations\doit\upstream.lock` 推导 staging 版本。

提交或交接前运行本地审计：

```powershell
.\scripts\sub2api-local-audit.ps1
```

推荐在刷新链路中直接附加审计和证据报告：

```powershell
.\scripts\sub2api-refresh-upstream.ps1 -CheckHttp -RunAudit -WriteReport
```

先运行预检：

```powershell
.\scripts\sub2api-promotion-preflight.ps1
```

预期：最后输出 `READY_FOR_EXPLICIT_PROMOTION_APPROVAL`。预检会检查 staging、旧项目健康状态、运行时保留路径，以及 `workbench\upstream-sync\reports\sub2api-upstream-report-latest.md` 是否匹配当前 target/staging 版本和官方 commit。这只说明具备替换条件，不代表已经替换。

```powershell
.\scripts\sub2api-promote-staging.ps1
```

预期：只打印 staging、target、backup、report、version、报告检查结果和保留路径，不替换当前项目。若报告检查不是 `report matches current versions`，不要执行替换，先重新运行：

```powershell
.\scripts\sub2api-refresh-upstream.ps1 -CheckHttp -RunAudit -WriteReport -RunPreflight
```

## 执行替换

执行前必须先停旧容器。`sub2api-promote-staging.ps1 -Execute` 默认会检查 `http://127.0.0.1:18082/health`，如果旧项目仍可访问，会拒绝热覆盖。

```powershell
cd sub2api\deploy
docker compose -f docker-compose.local.yml down
```

执行 promotion：

```powershell
cd ..\..
.\scripts\sub2api-promote-staging.ps1 -Execute
```

`-Execute` 会再次检查升级吸收报告是否匹配当前 target/staging 版本和官方 commit；报告缺失或过期时会拒绝替换。

只有在明确接受热覆盖风险时，才允许追加 `-AllowRunningTarget`。默认流程不要使用该参数。

替换后构建并启动：

```powershell
cd sub2api
docker build -f deploy\Dockerfile -t sub2api-doit:local .

cd deploy
$env:BIND_HOST='127.0.0.1'
$env:SERVER_PORT='18082'
docker compose -f docker-compose.local.yml up -d --force-recreate
```

验证：

```powershell
docker ps --filter "name=^/sub2api" --format "{{.Names}}`t{{.Status}}`t{{.Ports}}"
Invoke-WebRequest -Uri "http://127.0.0.1:18082/health" -UseBasicParsing
Invoke-WebRequest -Uri "http://127.0.0.1:18082/" -UseBasicParsing
```

## 回退

找到最新备份目录：

```powershell
Get-ChildItem .\backups\sub2api-promote | Sort-Object LastWriteTime -Descending | Select-Object -First 1
```

将备份源码恢复到 `sub2api`。运行时数据仍保留在原 `sub2api\deploy` 目录，回退前不要删除数据目录。
