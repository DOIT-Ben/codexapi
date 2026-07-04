# Doit API Upstream Sync

## 当前结论

Doit API 采用“官方 Sub2API 源码 + Doit 定制层”的吸收模式：

- 官方源码副本：`sub2api-official`
- 当前项目：`sub2api`
- Doit 定制层：`customizations\doit`
- 生成 staging：`workbench\upstream-sync\sub2api-doit-<version>`

当前 `sub2api` 已完成一次正式 promotion：从旧 `0.1.130` 吸收到 Doit 定制后的官方 `0.1.144`。以后官方更新仍按“刷新官方、生成 staging、验证、promotion”的流程执行。

## 推荐命令

日常开发统一入口：

```powershell
.\scripts\sub2api-dev.ps1 status
.\scripts\sub2api-dev.ps1 customization-check
.\scripts\sub2api-dev.ps1 refresh
.\scripts\sub2api-dev.ps1 upstream-watch
.\scripts\sub2api-dev.ps1 preflight
.\scripts\sub2api-dev.ps1 snapshot
.\scripts\sub2api-dev.ps1 gate
.\scripts\sub2api-dev.ps1 next-action
.\scripts\sub2api-dev.ps1 promote-dryrun
.\scripts\sub2api-dev.ps1 rollback-dryrun
```

刷新官方、套 Doit 定制、验证 staging、生成证据报告并运行 preflight：

```powershell
.\scripts\sub2api-refresh-upstream.ps1 -CheckHttp -RunAudit -RunCustomizationCheck -WriteReport -RunPreflight
```

只做本地审计：

```powershell
.\scripts\sub2api-local-audit.ps1
```

查看当前开发状态、官方副本、target/staging 版本和健康端点：

```powershell
.\scripts\sub2api-status.ps1
```

只做 promotion dry-run：

```powershell
.\scripts\sub2api-promote-staging.ps1
```

只做 push 前只读核验：

```powershell
.\scripts\sub2api-push-preflight.ps1
```

## 正式替换边界

不要直接执行正式替换，除非用户明确授权。

正式替换命令是：

```powershell
.\scripts\sub2api-promote-staging.ps1 -Execute
```

该命令会再次检查升级吸收报告是否匹配当前 target/staging 版本和官方 commit。报告缺失或过期时会拒绝替换。
该命令默认还会检查旧项目健康端点 `http://127.0.0.1:18082/health`。旧项目仍可访问时会拒绝热覆盖，必须先停旧容器再执行。
promotion dry-run 和 execute 都会写入 `workbench\upstream-sync\reports\sub2api-promotion-plan-latest.json`，记录版本、路径、备份位置、报告检查、健康检查和保留项。
promotion 回退 dry-run 和 execute 会写入 `workbench\upstream-sync\reports\sub2api-rollback-plan-latest.json`，记录备份路径、目标路径、版本、健康检查和保留项。
发布就绪快照会写入 `workbench\upstream-sync\reports\sub2api-release-snapshot-latest.json`，记录 git、官方、版本、健康、preflight 和 promotion/rollback plan 状态。
发布门禁会写入 `workbench\upstream-sync\reports\sub2api-release-gate-latest.json`，并在本地审计、git 同步、官方远端、健康检查和 promotion 状态满足时返回 PASS。门禁同时支持 promotion 前和 promotion 后两种状态。
官方更新观察会写入 `workbench\upstream-sync\reports\sub2api-upstream-watch-latest.json`，记录 lock commit、官方远端 commit、是否有新提交，以及下一步建议。
定制层一致性校验会写入 `workbench\upstream-sync\reports\sub2api-customization-check-latest.json`，逐项确认 manifest 声明的 overlay 已精确落到当前 staging，且主品牌替换已经应用。
下一步决策会写入 `workbench\upstream-sync\reports\sub2api-next-action-latest.json`，根据 upstream watch、release gate 和 promotion dry-run 判断当前应该刷新、修门禁、先停旧服务还是可以执行 promotion。

## 推送边界

不要直接 push，除非用户明确授权。

push 前先运行：

```powershell
.\scripts\sub2api-push-preflight.ps1
```

预期输出是 `Push preflight result: READY_TO_PUSH_WITH_EXPLICIT_APPROVAL`。

## 文档索引

- `2026-07-05-doit-upstream-sync-design.md`：方案设计和取舍。
- `2026-07-05-doit-upstream-sync-implementation-plan.md`：落地计划。
- `2026-07-05-doit-upstream-sync-status.md`：当前状态、验证证据和运行地址。
- `2026-07-05-doit-promotion-runbook.md`：正式替换和回退步骤。
- `2026-07-05-doit-release-handoff.md`：正式替换交接说明、证据命令、promotion 和 rollback 入口。
- `2026-07-05-doit-local-diff-inventory.md`：旧 `sub2api` 本地差异归档。

## 定制层索引

- `customizations\doit\README.md`：Doit overlay、active patch、retired patch 和更新流程。
- `customizations\doit\manifest.json`：Doit 定制层的机器可读清单，声明 active overlay、active patch、品牌替换和 retired patch。
- `customizations\doit\overlays\`：品牌、主题和布局覆盖文件。
- `customizations\doit\patches\`：仍自动应用的 patch。
- `customizations\doit\retired\`：历史 patch，只作证据，不自动应用。
