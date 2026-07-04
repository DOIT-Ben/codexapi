# Doit API 官方更新吸收设计

## 目标与成功标准

目标是在保留 Doit API 品牌、主题和本地部署习惯的前提下，快速吸收官方 Sub2API 的新功能与修复。当前阶段不直接覆盖 `sub2api\deploy\.env`、数据库目录、Redis 目录或生产数据。

成功标准：

- 官方来源明确：`https://github.com/Wei-Shaw/sub2api`。
- Doit 定制可以作为独立补丁层重复应用。
- 能从官方 `0.1.144` 生成一个 Doit 版本 staging 副本。
- staging 副本可以完成后端关键测试、前端构建和 HTTP 探活。
- 后续官方更新时，只需拉取官方、重放 Doit 补丁、验证，不再手工散改官方源码。

## 第一步：第一性原理梳理核心需求

这个项目的核心价值不是维护一个长期分叉的源码树，而是获得官方 Sub2API 持续迭代带来的网关、账号、计费、限流、后台和风控能力，同时保留我们面向 Doit API 的品牌表达与本地部署方式。

因此，长期目标应拆成两层：

- 官方源码层：尽量接近 `Wei-Shaw/sub2api`，用于快速吸收功能、修复和安全更新。
- Doit 定制层：只表达我们自己的差异，包括品牌名、颜色主题、logo/文案、本地镜像名、固定构建工具版本，以及确有必要的业务补丁。

如果继续直接在官方文件里散改，下一次官方更新时需要重新人工比对所有变化，冲突面会越来越大。相反，定制层越薄、越可重放，更新成本越稳定。

## 第二步：可复用方案调研

已核验的一手来源与本地证据：

- 官方仓库：`https://github.com/Wei-Shaw/sub2api`
- 官方当前 HEAD：`b650bdd68d25bad3e502b2e34efe775555da2eba`
- 官方版本：`0.1.144`
- 本地旧项目版本：`0.1.130`
- 本地工作区远程：`https://github.com/DOIT-Ben/codexapi.git`

成熟做法：

- Vendor + patch stack：将上游源码作为 vendor 层，项目差异保存为可重放 patch。
- Overlay compose：部署差异放到独立 compose 或 override 文件，避免改上游 compose。
- Brand/theme isolation：品牌、主题、文案尽量收敛到少量配置、样式和 i18n 文件。
- Staging-first update：先在 staging 目录生成新版本并验证，再决定是否替换当前 `sub2api`。

这些做法比直接 `git merge upstream/main` 更适合当前仓库，因为当前 `codexapi` 的 Git 历史是一次性导入，不是官方仓库的标准 fork 历史。

## 第三步：复用、适配和必要自研

复用：

- 复用官方 `sub2api-official` 作为上游源码来源。
- 复用官方 `0.1.144` 的 Codex/OpenAI、Grok、Claude、Antigravity、后台、计费和风控修复。
- 复用官方已有测试与构建命令。

适配：

- 将 Doit 品牌文字、主题色、登录页视觉与引导文案抽成补丁。
- 将 Docker 本地镜像名和 pnpm 固定版本抽成部署补丁。
- 在 staging 目录应用补丁，避免直接覆盖旧项目。

必要自研：

- 新增同步脚本，将官方副本复制到 staging，并按顺序应用 Doit 补丁。
- 新增锁定文件，记录当前吸收的官方版本、commit 和补丁顺序。
- 新增文档，说明后续更新流程和验证门槛。

当前后端 Codex 导入去重补丁不直接重放到官方 `0.1.144`。官方新版本已经引入更完整的 shared account、access-only 和 user/account 匹配逻辑，旧补丁只作为 retired 参考保留。

## 第四步：落地方案、风险和验证标准

落地方案：

1. 新建 `customizations\doit`，保存 README、锁定文件、补丁和 retired 补丁。
2. 新建 `scripts\sub2api-upstream-sync.ps1`，从 `sub2api-official` 生成 staging 副本。
3. 将当前 Doit 前端品牌/主题差异保存为 `customizations\doit\overlays`，由 overlay 脚本复制和替换。
4. 将本地 Docker 构建差异生成 `0002-doit-local-docker-build.patch`。
5. 将旧后端 Codex 导入补丁和旧版本品牌 diff 保存到 `retired`，不默认应用。
6. 在 staging 副本上应用 active patch 和 overlay，并验证。
7. 验证通过后，再由用户确认是否将 staging 替换为当前 `sub2api`。

风险：

- 官方文件结构变化会导致 patch apply 失败，需要人工调整补丁。
- 品牌文案如果散落在新官方文件里，当前补丁可能覆盖不全，需要补充搜索验证。
- Docker 容器名仍可能与旧项目冲突，验证时要使用不同端口或先停旧容器。
- `.env` 和数据目录不得参与复制、提交或日志输出。

验证标准：

- `git apply --check` 对所有 active patch 通过，overlay 脚本真实修改 staging 文件。
- staging 中 `backend\cmd\server\VERSION` 为官方目标版本。
- 后端至少运行 Codex 导入相关测试。
- 前端执行 `pnpm run build`。
- Docker 或本地服务启动后，`/health` 和首页 HTTP 返回 200。
- 标准验证入口为 `scripts\sub2api-verify-staging.ps1`；需要连同 HTTP 探活时加 `-CheckHttp`。
- 标准刷新入口为 `scripts\sub2api-refresh-upstream.ps1`，用于串联官方 fetch、staging 生成、lock 更新和验证。
