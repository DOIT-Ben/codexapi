# Doit API Upstream Sync Status

## 当前结论

当前已完成官方 Sub2API `0.1.144` 到 Doit API staging 的吸收验证。旧项目仍保持不变，正式替换当前 `sub2api` 仍需要单独明确授权。

## 当前版本

- 当前旧项目：`sub2api`，版本 `0.1.130`
- 新版 staging：`workbench\upstream-sync\sub2api-doit-0.1.144`，版本 `0.1.144`
- 官方来源：`https://github.com/Wei-Shaw/sub2api`
- 官方 commit：`b650bdd68d25bad3e502b2e34efe775555da2eba`

## 当前运行地址

- 旧项目：`http://127.0.0.1:18082/`
- 新版 staging：`http://127.0.0.1:18083/`

## 已落地资产

- `scripts\sub2api-dev.ps1`
- `customizations\doit\apply-doit-overlay.ps1`
- `customizations\doit\manifest.json`
- `customizations\doit\docker-compose.staging.yml`
- `customizations\doit\overlays\`
- `customizations\doit\patches\0002-doit-local-docker-build.patch`
- `customizations\doit\retired\`
- `docs\upstream-sync\README.md`
- `docs\upstream-sync\2026-07-05-doit-local-diff-inventory.md`
- `scripts\sub2api-upstream-sync.ps1`
- `scripts\sub2api-refresh-upstream.ps1`
- `scripts\sub2api-status.ps1`
- `scripts\sub2api-verify-staging.ps1`
- `scripts\sub2api-staging-compose.ps1`
- `scripts\sub2api-local-audit.ps1`
- `scripts\sub2api-upstream-report.ps1`
- `scripts\sub2api-promotion-preflight.ps1`
- `scripts\sub2api-push-preflight.ps1`
- `scripts\sub2api-promote-staging.ps1`

## 验证证据

完整 staging 验证命令：

```powershell
.\scripts\sub2api-verify-staging.ps1 -CheckHttp
```

结果：

- staging 目录存在。
- staging 版本为 `0.1.144`。
- `Doit API` 品牌在主品牌文件中存在。
- 主品牌文件中的 `Sub2API` 残留为 0。
- Doit 主题色存在。
- Docker 可用于后端测试。
- 后端 Codex 重点测试通过：`go test ./internal/handler/admin -run Codex -count=1`。
- 前端 `pnpm install --frozen-lockfile` 通过。
- 前端 `pnpm run build` 通过。
- staging `/health` 返回 200。
- 最终输出：`Verification result: PASS`。

前端构建存在 Vite 常规警告：

- Browserslist 数据较旧。
- 部分动态导入与静态导入同时存在。
- 部分 chunk 超过 500 kB。

这些警告未导致构建失败，也不是本次 Doit overlay 引入的新阻断项。

## Promotion 状态

promotion 预检命令：

```powershell
.\scripts\sub2api-promotion-preflight.ps1
```

结果：

```text
Preflight result: READY_FOR_EXPLICIT_PROMOTION_APPROVAL
```

含义：当前具备替换条件，但尚未执行替换。正式替换会停旧容器并替换当前 `sub2api` 源码目录，必须另行明确授权。

## 安全边界

当前未覆盖以下运行时资产：

- `sub2api\deploy\.env`
- `sub2api\deploy\data`
- `sub2api\deploy\postgres_data`
- `sub2api\deploy\redis_data`

`.gitignore` 已忽略：

- `sub2api-official\`
- `workbench\upstream-sync\`
- `graphify-out\`
- `sub2api\backend\sub2api-new`
- `workbench\*.png`
- `workbench\image-test-*.json`

staging 容器状态入口：

```powershell
.\scripts\sub2api-staging-compose.ps1 status
.\scripts\sub2api-staging-compose.ps1 health
```

该脚本默认从 `customizations\doit\upstream.lock` 读取 `upstream_version`，并据此推导 staging 路径和镜像标签；官方版本升级后不需要手工改脚本默认值。

后续一键刷新入口：

```powershell
.\scripts\sub2api-refresh-upstream.ps1
```

包含 HTTP 检查和本地审计：

```powershell
.\scripts\sub2api-refresh-upstream.ps1 -CheckHttp -RunAudit
```

推荐的刷新、审计和证据报告一体化入口：

```powershell
.\scripts\sub2api-refresh-upstream.ps1 -CheckHttp -RunAudit -WriteReport
```

如只想验证当前 staging，不拉取官方、不重建 staging：

```powershell
.\scripts\sub2api-refresh-upstream.ps1 -SkipFetch -SkipSync -SkipFrontendBuild -CheckHttp
```

提交或交接前本地审计入口：

```powershell
.\scripts\sub2api-local-audit.ps1
```

升级吸收证据报告入口：

```powershell
.\scripts\sub2api-upstream-report.ps1 -CheckHttp -ReportPath .\workbench\upstream-sync\reports\sub2api-upstream-report-latest.md
```

## 2026-07-05 链路复验

完整 staging 验证已复跑：

```powershell
.\scripts\sub2api-verify-staging.ps1 -CheckHttp
```

结果：后端 Codex 重点测试、前端依赖安装、前端生产构建和 staging HTTP 健康检查均通过。构建输出仍有 Vite/Browserslist 常规警告，但未导致失败。

已验证新增的刷新链路审计参数：

```powershell
.\scripts\sub2api-refresh-upstream.ps1 -SkipFetch -SkipSync -SkipFrontendBuild -CheckHttp -RunAudit
```

已验证刷新链路可同时生成证据报告：

```powershell
.\scripts\sub2api-refresh-upstream.ps1 -SkipFetch -SkipSync -SkipFrontendBuild -CheckHttp -RunAudit -WriteReport
```

已验证刷新链路可串联 promotion preflight：

```powershell
.\scripts\sub2api-refresh-upstream.ps1 -SkipFetch -SkipSync -SkipFrontendBuild -CheckHttp -RunAudit -WriteReport -RunPreflight
```

该链路已修正为先生成 `sub2api-upstream-report-latest.md`，再运行 promotion preflight。已删除旧报告后复验通过，证明 preflight 使用的是同次刷新生成的新报告。

结果：

- 官方副本仍在 commit `b650bdd68d25bad3e502b2e34efe775555da2eba`。
- `git fetch origin main --tags --prune` 后，官方 `origin/main` 仍为 `b650bdd68d25bad3e502b2e34efe775555da2eba`，没有比当前 staging 更新的提交。
- 官方版本仍为 `0.1.144`。
- staging 验证通过，`http://127.0.0.1:18083/health` 返回 200。
- 本地审计通过，`http://127.0.0.1:18082/health` 与 `http://127.0.0.1:18083/health` 均返回 200。
- 升级吸收证据报告已生成到 `workbench\upstream-sync\reports\sub2api-upstream-report-latest.md`。
- 刷新、审计、证据报告和 promotion preflight 一体化入口已通过，最终输出 `Refresh result: PASS`。
- promotion preflight 已接入证据报告一致性检查，并验证通过：`upstream absorption report - report matches current versions`。
- promotion dry-run 已接入证据报告一致性检查，并验证通过：`report check: report matches current versions`；正式 `-Execute` 会在替换前再次执行该门禁。
- promotion dry-run 和 execute 已接入机器可读 JSON 计划：`workbench\upstream-sync\reports\sub2api-promotion-plan-latest.json`。
- promotion 回退已接入 dry-run、运行态保护和机器可读 JSON 计划：`workbench\upstream-sync\reports\sub2api-rollback-plan-latest.json`。
- 发布就绪快照已接入机器可读 JSON：`workbench\upstream-sync\reports\sub2api-release-snapshot-latest.json`。
- 本地审计已扩展上游吸收资产完整性门禁，验证通过：`required upstream-sync assets are present - 29/29`。
- 本地审计已扩展生成物忽略门禁，验证通过：`generated/local artifact paths are git-ignored - 7/7`。
- 本地审计已扩展旧项目差异归档门禁，验证通过：`local sub2api diffs are inventoried - 10/10`。以后旧 `sub2api` 新增 modified 文件时，必须同步更新 `docs\upstream-sync\2026-07-05-doit-local-diff-inventory.md`。
- 本地审计已扩展可见未跟踪文件范围门禁，验证通过：`visible untracked files are expected project assets - 28 untracked assets in expected roots`。
- 本地审计已扩展官方副本来源门禁，验证通过：`official upstream clone is clean and locked - clean official clone at b650bdd68d25bad3e502b2e34efe775555da2eba`。
- `scripts\sub2api-*.ps1` 中不再硬编码 `sub2api-doit-0.1.144`、`0.1.144-staging` 或固定 `ExpectedVersion = "0.1.144"`。
- 当前正式替换仍未执行，`sub2api` 目录保持旧项目状态。
