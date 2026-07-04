# Doit API Release Handoff

## 当前结论

当前 `0.1.144` staging 已完成正式 promotion，当前 `sub2api` 已从 `0.1.130` 替换为 Doit 定制后的官方 `0.1.144`。旧运行数据、`.env` 和本地配置已由 promotion 脚本保留，未在文档或日志中展开敏感值。

当前下一步决策：

```text
PROMOTED_VERIFY_AND_COMMIT
```

含义：官方无新提交、发布门禁通过、target 与 staging 均为 `0.1.144`，当前需要提交并推送这次正式吸收结果。

## 当前版本

- 当前项目：`sub2api`，版本 `0.1.144`
- 当前 staging：`workbench\upstream-sync\sub2api-doit-0.1.144`，版本 `0.1.144`
- 官方仓库：`https://github.com/Wei-Shaw/sub2api.git`
- 官方 commit：`b650bdd68d25bad3e502b2e34efe775555da2eba`

## 当前运行地址

- 当前项目：`http://127.0.0.1:18082`
- staging：`http://127.0.0.1:18083`

## 必跑证据命令

当前只读门禁：

```powershell
.\scripts\sub2api-dev.ps1 upstream-watch
.\scripts\sub2api-dev.ps1 gate -CheckRemote
.\scripts\sub2api-dev.ps1 next-action
```

预期：

- `upstream-watch` 输出 `NO_UPDATE`
- `gate` 输出 `Release gate result: PASS`
- `next-action` 输出 `PROMOTED_VERIFY_AND_COMMIT`

## 已执行的正式替换命令

已在用户授权后执行：

```powershell
cd sub2api\deploy
docker compose -f docker-compose.local.yml down
cd ..\..
.\scripts\sub2api-promote-staging.ps1 -Execute
```

替换后构建并启动：

```powershell
cd sub2api
docker build -f deploy\Dockerfile -t sub2api-doit:local .

cd deploy
$env:BIND_HOST='127.0.0.1'
$env:SERVER_PORT='18082'
docker compose -f docker-compose.local.yml up -d --force-recreate
```

替换后验证：

```powershell
Invoke-WebRequest -Uri "http://127.0.0.1:18082/health" -UseBasicParsing
.\scripts\sub2api-dev.ps1 gate -CheckRemote
```

当前验证结果：

- `docker build -f deploy\Dockerfile -t sub2api-doit:local .` 通过。
- `docker compose -f docker-compose.local.yml up -d --force-recreate` 通过。
- `http://127.0.0.1:18082/health` 返回 200。
- `.\scripts\sub2api-dev.ps1 gate -CheckRemote` 输出 `Release gate result: PASS`。
- 回退备份目录：`backups\sub2api-promote\sub2api_20260705-030733`。

## 回退入口

先 dry-run：

```powershell
.\scripts\sub2api-dev.ps1 rollback-dryrun
```

确认目标服务已停止后执行回退：

```powershell
.\scripts\sub2api-rollback-promotion.ps1 -Execute
```

## 机器可读证据

这些文件在 `workbench\upstream-sync\reports\` 下，属于本地生成物，不提交：

- `sub2api-upstream-watch-latest.json`
- `sub2api-customization-check-latest.json`
- `sub2api-release-snapshot-latest.json`
- `sub2api-release-gate-latest.json`
- `sub2api-promotion-plan-latest.json`
- `sub2api-rollback-plan-latest.json`
- `sub2api-next-action-latest.json`

## 不要做的事

- 不要直接把官方仓库 merge 到旧 `sub2api`。
- 不要提交 `sub2api\deploy\.env`、运行数据目录、staging 运行数据目录或任何 token、账号、密钥。
- 不要输出 `sub2api\deploy\.env` 或任何 token、账号、密钥。
- 不要在旧服务仍运行时强行传 `-AllowRunningTarget`，除非明确接受热覆盖风险。

## 提交状态

上游吸收框架、定制 manifest、发布门禁、promotion 计划、rollback 入口、官方更新观察、定制一致性校验、下一步决策入口均已推送到远程 `origin/main`。当前正式 promotion 产生的 `sub2api` 源码升级和 post-promotion 脚本修复仍需提交。
