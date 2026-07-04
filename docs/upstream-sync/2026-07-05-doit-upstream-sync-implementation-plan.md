# Doit API Upstream Sync Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a repeatable workflow that generates a Doit API staging copy from official Sub2API and reapplies only our small customization layer.

**Architecture:** Treat `sub2api-official` as the upstream source and `customizations\doit` as the Doit overlay. A PowerShell sync script creates a staging copy under `workbench\upstream-sync`, applies active patches in order, and leaves current `sub2api` untouched until a separate replacement decision.

**Tech Stack:** PowerShell, Git patch files, Go, Vue 3, Vite, TailwindCSS, Docker Compose.

---

### Task 1: Create Documentation And Customization Layout

**Files:**
- Create: `docs\upstream-sync\2026-07-05-doit-upstream-sync-design.md`
- Create: `docs\upstream-sync\2026-07-05-doit-upstream-sync-implementation-plan.md`
- Create: `customizations\doit\README.md`
- Create: `customizations\doit\upstream.lock`
- Create: `customizations\doit\patches\.gitkeep`
- Create: `customizations\doit\retired\.gitkeep`

- [ ] **Step 1: Create docs and directories**

Create the files above. The design document must include first-principles requirements, upstream evidence, reuse strategy, implementation plan, risks, and verification.

- [ ] **Step 2: Verify layout**

Run:

```powershell
Get-ChildItem .\customizations\doit -Recurse | Select-Object FullName
```

Expected: README, lock file, active patch directory, and retired patch directory are visible.

### Task 2: Extract Current Doit Patches

**Files:**
- Create: `customizations\doit\apply-doit-overlay.ps1`
- Create: `customizations\doit\overlays\frontend\tailwind.config.js`
- Create: `customizations\doit\overlays\frontend\src\style.css`
- Create: `customizations\doit\overlays\frontend\src\components\layout\AppLayout.vue`
- Create: `customizations\doit\overlays\frontend\src\components\layout\AuthLayout.vue`
- Create: `customizations\doit\patches\0002-doit-local-docker-build.patch`
- Create: `customizations\doit\retired\0001-legacy-codex-import-shared-account.patch`
- Create: `customizations\doit\retired\0002-old-version-branding-theme-diff.patch`

- [ ] **Step 1: Create active frontend overlay**

Copy the current Doit theme files into `customizations\doit\overlays`, then use `apply-doit-overlay.ps1` to copy them into staging and replace `Sub2API` with `Doit API` in official i18n files.

- [ ] **Step 2: Generate retired old-version frontend patch**

Run:

```powershell
git diff --relative=sub2api --output=customizations\doit\retired\0002-old-version-branding-theme-diff.patch -- sub2api\frontend\src\components\layout\AppLayout.vue sub2api\frontend\src\components\layout\AuthLayout.vue sub2api\frontend\src\i18n\locales\en.ts sub2api\frontend\src\i18n\locales\zh.ts sub2api\frontend\src\style.css sub2api\frontend\tailwind.config.js
```

Expected: old diff is retained for reference but not applied automatically.

- [ ] **Step 3: Generate active Docker patch**

Run:

```powershell
git diff --relative=sub2api --output=customizations\doit\patches\0002-doit-local-docker-build.patch -- sub2api\deploy\Dockerfile sub2api\deploy\docker-compose.local.yml
```

Expected: patch contains pnpm pinning and local image override.

- [ ] **Step 4: Generate retired backend patch**

Run:

```powershell
git diff --relative=sub2api --output=customizations\doit\retired\0001-legacy-codex-import-shared-account.patch -- sub2api\backend\internal\handler\admin\account_codex_import.go sub2api\backend\internal\handler\admin\account_codex_import_test.go
```

Expected: patch is saved for reference but not applied by the sync script.

### Task 3: Build The Staging Sync Script

**Files:**
- Create: `scripts\sub2api-upstream-sync.ps1`

- [ ] **Step 1: Implement guarded staging copy**

The script must resolve repo root, verify `sub2api-official` exists, remove only the staging path when `-Force` is passed, copy official files excluding `.git`, and never touch `sub2api\deploy\.env` or data directories.

- [ ] **Step 2: Implement patch check, apply, and overlay**

For each `customizations\doit\patches\*.patch`, run `git -C <staging> apply --check <patch>` before `git -C <staging> apply <patch>`.
Then run `customizations\doit\apply-doit-overlay.ps1 -TargetPath <staging>`.

- [ ] **Step 3: Print a redacted summary**

The script should print official source, staging path, applied patches, and VERSION. It must not print secrets or `.env` content.

### Task 4: Generate Official 0.1.144 Doit Staging

**Files:**
- Generated: `workbench\upstream-sync\sub2api-doit-0.1.144`

- [ ] **Step 1: Run sync script**

Run:

```powershell
.\scripts\sub2api-upstream-sync.ps1 -Force
```

Expected: staging directory exists and both active patches are applied.

- [ ] **Step 2: Verify version**

Run:

```powershell
Get-Content .\workbench\upstream-sync\sub2api-doit-0.1.144\backend\cmd\server\VERSION
```

Expected: `0.1.144`.

### Task 5: Validate Staging

**Files:**
- Read: `workbench\upstream-sync\sub2api-doit-0.1.144`
- Create: `scripts\sub2api-verify-staging.ps1`

- [ ] **Step 1: Run backend focused tests**

Run:

```powershell
cd .\workbench\upstream-sync\sub2api-doit-0.1.144\backend
go test .\internal\handler\admin -run Codex -count=1
```

Expected: exit code 0.

- [ ] **Step 2: Run frontend build**

Run:

```powershell
cd .\workbench\upstream-sync\sub2api-doit-0.1.144\frontend
pnpm install --frozen-lockfile
pnpm run build
```

Expected: exit code 0.

- [ ] **Step 3: Run the consolidated verification script**

Run:

```powershell
.\scripts\sub2api-verify-staging.ps1 -CheckHttp
```

Expected: `Verification result: PASS`.

- [ ] **Step 4: Prepare Docker verification**

Use a non-conflicting port and avoid overwriting existing containers. If compose still uses fixed container names, stop and remove only the staging containers created for the verification, or ask for replacement approval before switching the current running instance.
