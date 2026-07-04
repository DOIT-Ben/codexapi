# Doit API Customization Layer

This directory contains the Doit-specific overlay for official Sub2API.

## Manifest

`manifest.json` is the machine-readable source of truth for Doit customizations. It lists the active overlay files, active patches, brand replacement rules, brand replacement target files, and retired patches.

## Active Overlay

`apply-doit-overlay.ps1` copies maintained Doit theme files into the generated staging copy and applies brand replacements to official i18n files.

Overlay files live in `overlays\`:

- `frontend\tailwind.config.js`
- `frontend\src\style.css`
- `frontend\src\components\layout\AppLayout.vue`
- `frontend\src\components\layout\AuthLayout.vue`

Keep this list synchronized through `manifest.json`; scripts read the manifest instead of scanning the directory.

## Active Patches

Active patches live in `patches\` and are applied in filename order by `scripts\sub2api-upstream-sync.ps1`.

- `0002-doit-local-docker-build.patch`: local Docker image name and pinned pnpm build version.

Active patches are applied in the exact order declared by `manifest.json`.

## Retired Patches

Retired patches live in `retired\` for historical reference and are not applied automatically.

- `0001-legacy-codex-import-shared-account.patch`: old local Codex import de-duplication patch. Official `0.1.144` contains a broader implementation, so this patch is kept only as evidence.
- `0002-old-version-branding-theme-diff.patch`: old `0.1.130`-based branding diff. It is not reliable against official `0.1.144`, so branding now uses the overlay script.

## Update Flow

1. Fetch official Sub2API into `sub2api-official`.
2. Run `scripts\sub2api-upstream-sync.ps1 -Force`.
3. Validate the generated staging copy:
   `scripts\sub2api-verify-staging.ps1 -CheckHttp`
4. Replace current `sub2api` only after validation and explicit approval.

For the combined fetch/sync/verify flow, run:

```powershell
scripts\sub2api-refresh-upstream.ps1
```

To include local audit and HTTP checks:

```powershell
scripts\sub2api-refresh-upstream.ps1 -CheckHttp -RunAudit
```

Recommended update command before promotion:

```powershell
scripts\sub2api-refresh-upstream.ps1 -CheckHttp -RunAudit -WriteReport
```

To generate a read-only absorption report before promotion:

```powershell
scripts\sub2api-upstream-report.ps1 -CheckHttp -ReportPath .\workbench\upstream-sync\reports\sub2api-upstream-report-latest.md
```

The report lists the official commit/version, current target version, generated staging version, active overlay files, active patches, patch-touched files, preserved runtime paths, and optional HTTP health results.

## Safety Rules

- Do not commit `.env`, database data, Redis data, logs, tokens, or generated secrets.
- Do not apply retired patches unless a fresh review proves they are still needed.
- Prefer changing this overlay instead of editing upstream files directly.
