# Doit API Local Diff Inventory

## 目标

记录当前旧项目 `sub2api` 中仍显示为 modified 的本地差异，并说明这些差异在上游吸收方案中的归属。该清单用于正式 promotion 前确认：哪些差异会进入新版 staging，哪些只作为历史参考保留，避免替换旧目录时误判为丢改动。

## 当前旧项目修改文件

以下路径来自：

```powershell
git diff --name-only -- sub2api
```

- `sub2api\backend\internal\handler\admin\account_codex_import.go`
- `sub2api\backend\internal\handler\admin\account_codex_import_test.go`
- `sub2api\deploy\Dockerfile`
- `sub2api\deploy\docker-compose.local.yml`
- `sub2api\frontend\src\components\layout\AppLayout.vue`
- `sub2api\frontend\src\components\layout\AuthLayout.vue`
- `sub2api\frontend\src\i18n\locales\en.ts`
- `sub2api\frontend\src\i18n\locales\zh.ts`
- `sub2api\frontend\src\style.css`
- `sub2api\frontend\tailwind.config.js`

## 差异归属表

| 旧项目路径 | 定制层归属 | 当前策略 |
| --- | --- | --- |
| `sub2api\frontend\src\components\layout\AppLayout.vue` | `customizations\doit\overlays\frontend\src\components\layout\AppLayout.vue` | active overlay，继续套到官方新版 |
| `sub2api\frontend\src\components\layout\AuthLayout.vue` | `customizations\doit\overlays\frontend\src\components\layout\AuthLayout.vue` + brand replacement | active overlay，继续套到官方新版 |
| `sub2api\frontend\src\style.css` | `customizations\doit\overlays\frontend\src\style.css` | active overlay，继续套到官方新版 |
| `sub2api\frontend\tailwind.config.js` | `customizations\doit\overlays\frontend\tailwind.config.js` | active overlay，继续套到官方新版 |
| `sub2api\frontend\src\i18n\locales\en.ts` | `customizations\doit\apply-doit-overlay.ps1` brand replacement | 不维护整文件 overlay，只做品牌替换 |
| `sub2api\frontend\src\i18n\locales\zh.ts` | `customizations\doit\apply-doit-overlay.ps1` brand replacement | 不维护整文件 overlay，只做品牌替换 |
| `sub2api\deploy\Dockerfile` | `customizations\doit\patches\0002-doit-local-docker-build.patch` | active patch，继续套到官方新版 |
| `sub2api\deploy\docker-compose.local.yml` | `customizations\doit\patches\0002-doit-local-docker-build.patch` | active patch，继续套到官方新版 |
| `sub2api\backend\internal\handler\admin\account_codex_import.go` | `customizations\doit\retired\0001-legacy-codex-import-shared-account.patch` | retired，不默认套用；官方 `0.1.144` 已有更完整实现 |
| `sub2api\backend\internal\handler\admin\account_codex_import_test.go` | `customizations\doit\retired\0001-legacy-codex-import-shared-account.patch` | retired，不默认套用；官方 `0.1.144` 已有更完整实现 |

## 结论

当前旧项目里显示为 modified 的本地差异没有未归档项：

- 品牌和主题差异已抽到 active overlay 和 brand replacement。
- 本地 Docker 构建差异已抽到 active patch。
- 旧 Codex 导入去重差异已放入 retired patch，仅作为历史证据保留。

后续正式 promotion 替换 `sub2api` 前，不需要从旧目录手工复制这些文件；应以 `customizations\doit` 为唯一 Doit 定制来源。
