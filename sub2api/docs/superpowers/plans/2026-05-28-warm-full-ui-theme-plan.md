# Warm Full UI Theme Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the current cool teal Sub2API frontend into a warm, full, commercial API gateway UI inspired by NexaHub AI without copying it.

**Architecture:** Keep the existing Vue/Tailwind component system and make the broadest visual change through theme tokens and global component classes first. Then refine the shell, auth layout, dashboard surfaces, and operations console only where global styling is not enough.

**Tech Stack:** Vue 3, Vite, Tailwind CSS, TypeScript, Vitest, vue-tsc.

---

## File Structure

- Modify `frontend/tailwind.config.js`: replace primary palette and warm shadow/gradient tokens.
- Modify `frontend/src/style.css`: update global button, card, input, badge, table, sidebar, page header, empty-state, glass, and background utility classes.
- Modify `frontend/src/components/layout/AppLayout.vue`: use warm page background and keep the mesh subtle.
- Modify `frontend/src/components/layout/AppHeader.vue`: use warm header borders, balance pill, avatar gradient, and utility-link hover states.
- Modify `frontend/src/components/layout/AppSidebar.vue`: refine logo shadow, section dividers, bottom border, and scoped sidebar helper CSS.
- Modify `frontend/src/components/layout/AuthLayout.vue`: warm branded auth surface.
- Modify `frontend/src/views/user/DashboardView.vue`: refine high-visibility user dashboard cards and calls to action if inherited styling is insufficient.
- Modify `frontend/src/views/admin/DashboardView.vue`: refine admin stat cards while keeping dense scanning.
- Modify `frontend/src/views/admin/OperationsConsoleView.vue`: align new operations console with the warm full theme.
- Add/modify tests only where class-based assertions require updates.

## Task 1: Theme Tokens And Global Components

**Files:**
- Modify: `frontend/tailwind.config.js`
- Modify: `frontend/src/style.css`

- [ ] **Step 1: Inspect current theme token usage**

Run:

```bash
rg -n "primary-|shadow-|bg-mesh-gradient|btn-primary|card|input|badge|sidebar-link-active" frontend/src frontend/tailwind.config.js
```

Expected: output shows global classes in `frontend/src/style.css` and layout/page use sites.

- [ ] **Step 2: Update warm primary palette and shadows**

In `frontend/tailwind.config.js`, set `primary` to a warm clay scale:

```js
primary: {
  50: '#fff7ed',
  100: '#ffedd5',
  200: '#fed7aa',
  300: '#fdba74',
  400: '#f59f5b',
  500: '#e48556',
  600: '#c96442',
  700: '#a84d34',
  800: '#843d2d',
  900: '#6b3428',
  950: '#3a1a12'
}
```

Update shadows and gradients:

```js
boxShadow: {
  glass: '0 18px 50px rgba(94, 59, 35, 0.10)',
  'glass-sm': '0 8px 24px rgba(94, 59, 35, 0.08)',
  glow: '0 0 22px rgba(228, 133, 86, 0.28)',
  'glow-lg': '0 0 44px rgba(228, 133, 86, 0.34)',
  card: '0 1px 2px rgba(58, 51, 42, 0.05), 0 10px 30px rgba(106, 71, 45, 0.07)',
  'card-hover': '0 16px 44px rgba(106, 71, 45, 0.12)',
  'inner-glow': 'inset 0 1px 0 rgba(255, 250, 244, 0.72)'
}
```

Update background gradients:

```js
backgroundImage: {
  'gradient-radial': 'radial-gradient(var(--tw-gradient-stops))',
  'gradient-primary': 'linear-gradient(135deg, #e48556 0%, #c96442 100%)',
  'gradient-dark': 'linear-gradient(135deg, #2d241e 0%, #14100d 100%)',
  'gradient-glass': 'linear-gradient(135deg, rgba(255,250,244,0.72) 0%, rgba(255,247,237,0.48) 100%)',
  'mesh-gradient':
    'radial-gradient(at 24% 12%, rgba(228, 133, 86, 0.13) 0px, transparent 44%), radial-gradient(at 82% 4%, rgba(201, 100, 66, 0.10) 0px, transparent 42%), radial-gradient(at 5% 54%, rgba(253, 186, 116, 0.10) 0px, transparent 46%)'
}
```

- [ ] **Step 3: Update global component classes**

In `frontend/src/style.css`, update:

- `body`: warm background.
- `::selection`: warm selection.
- `.btn-primary`, `.btn-secondary`, `.btn-ghost`: warm full states.
- `.input`: warm border/fill/focus.
- `.glass`, `.glass-card`, `.card`, `.card-hover`, `.card-header`, `.card-footer`: warm surfaces.
- `.stat-icon-primary`, `.badge-primary`, `.badge-gray`, `.dropdown`, `.table-container`, `.table th`, `.table tbody tr`, `.sidebar`, `.sidebar-header`, `.sidebar-link`, `.sidebar-link-active`, `.page-title`, `.page-description`, `.empty-state-icon`.

Use Tailwind utilities where possible. Use literal CSS only for warm colors not in the palette, for example:

```css
body {
  background-color: #f7f2ea;
}

.dark body {
  background-color: #100d0b;
}
```

- [ ] **Step 4: Run fast CSS/build sanity**

Run:

```bash
cd frontend
pnpm vite build
```

Expected: build completes. Chunk-size warnings are acceptable; CSS/Tailwind errors are not.

## Task 2: Core Shell Warm Branding

**Files:**
- Modify: `frontend/src/components/layout/AppLayout.vue`
- Modify: `frontend/src/components/layout/AppHeader.vue`
- Modify: `frontend/src/components/layout/AppSidebar.vue`
- Test: `frontend/src/components/layout/__tests__/AppSidebar.spec.ts`

- [ ] **Step 1: Update shell surfaces**

In `AppLayout.vue`, change the outer background class from cool gray to warm arbitrary colors:

```vue
<div class="min-h-screen bg-[#f7f2ea] text-[#3a332a] dark:bg-[#100d0b] dark:text-gray-100">
```

Keep `bg-mesh-gradient`, but it should remain pointer-events-none and subtle.

- [ ] **Step 2: Update header visual states**

In `AppHeader.vue`:

- Change header border to warm border:

```vue
<header class="glass sticky top-0 z-30 border-b border-[#e4dacb]/70 dark:border-[#3b2a22]/70">
```

- Change docs link hover to warm tint.
- Change balance pill to warm primary tint:

```vue
class="hidden items-center gap-2 rounded-xl bg-primary-100/80 px-3 py-1.5 shadow-sm shadow-primary-500/10 dark:bg-primary-900/30 sm:flex"
```

- Change avatar gradient to:

```vue
class="flex h-8 w-8 items-center justify-center overflow-hidden rounded-xl bg-gradient-to-br from-primary-400 to-primary-700 text-sm font-medium text-white shadow-sm shadow-primary-500/30"
```

- [ ] **Step 3: Update sidebar scoped warm details**

In `AppSidebar.vue`:

- Update logo shadow utility from `shadow-glow` to `shadow-glow ring-1 ring-primary-200/70 dark:ring-primary-800/60`.
- Update the bottom section border from gray to warm border:

```vue
<div class="mt-auto border-t border-[#eadfce] p-3 dark:border-[#33241e]">
```

- Update child group border from gray to warm border:

```vue
class="mb-1 ml-4 border-l border-[#e4dacb] pl-2 dark:border-[#463229]"
```

- Update scoped `.sidebar-section-title::after` colors to warm neutrals:

```css
background: rgb(228 218 203);
```

and dark:

```css
background: rgb(70 50 41);
```

- [ ] **Step 4: Run sidebar test**

Run:

```bash
cd frontend
pnpm vitest --run src/components/layout/__tests__/AppSidebar.spec.ts
```

Expected: test passes or only class-string expectations need a narrow update.

## Task 3: Auth And High-Visibility Dashboard Polish

**Files:**
- Modify: `frontend/src/components/layout/AuthLayout.vue`
- Modify: `frontend/src/views/auth/LoginView.vue`
- Modify: `frontend/src/views/user/DashboardView.vue`
- Modify: `frontend/src/views/admin/DashboardView.vue`

- [ ] **Step 1: Inspect auth and dashboard markup**

Run:

```bash
rg -n "card-glass|bg-gradient|from-primary|card p-|stat-card|btn-primary|page-header" frontend/src/components/layout/AuthLayout.vue frontend/src/views/auth/LoginView.vue frontend/src/views/user/DashboardView.vue frontend/src/views/admin/DashboardView.vue
```

Expected: identify page-level classes that may need warm full refinements.

- [ ] **Step 2: Warm auth layout**

In `AuthLayout.vue`, make the auth background and card use the warm theme. Preserve existing slots and logic. Prefer changing class strings only.

Expected shape:

```vue
<div class="min-h-screen bg-[#f7f2ea] ... dark:bg-[#100d0b]">
```

The auth card should retain `card-glass` but add warm border/shadow if needed:

```vue
<div class="card-glass rounded-2xl border border-[#eadfce]/80 p-8 shadow-glass dark:border-[#3b2a22]/80">
```

- [ ] **Step 3: Refine dashboard cards only if needed**

Use inherited `.card`, `.stat-card`, `.stat-icon-primary`, `.btn-primary`, and `.badge-primary` first. If a page still looks flat, add only narrow warm classes to high-value cards:

```vue
class="card border-[#eadfce] bg-[#fffaf4] p-4 dark:border-[#3b2a22] dark:bg-dark-800/70"
```

Do not change data loading, computed values, API calls, or routes.

- [ ] **Step 4: Run dashboard/auth-related tests if present**

Run:

```bash
cd frontend
pnpm vitest --run src/components/__tests__/LoginForm.spec.ts src/views/admin/__tests__/DashboardView.spec.ts
```

Expected: tests pass. If a test fails due to class string expectations, update only the expectation.

## Task 4: Operations Console Theme Alignment

**Files:**
- Modify: `frontend/src/views/admin/OperationsConsoleView.vue`
- Test: `frontend/src/views/admin/__tests__/OperationsConsoleView.spec.ts`

- [ ] **Step 1: Inspect operations console class usage**

Run:

```bash
rg -n "card|bg-|border-|text-|btn|badge|primary|gray|dark" frontend/src/views/admin/OperationsConsoleView.vue
```

Expected: identify local cold gray/teal styling that should inherit the warm theme.

- [ ] **Step 2: Replace local cold styling with global classes**

Prefer existing classes:

- `card`
- `card-header`
- `card-body`
- `btn btn-primary`
- `btn btn-secondary`
- `badge badge-primary`
- `badge badge-warning`
- `badge badge-danger`

Keep warning/danger states semantic. Do not make outage/error states orange.

- [ ] **Step 3: Run operations console tests**

Run:

```bash
cd frontend
pnpm vitest --run src/views/admin/__tests__/OperationsConsoleView.spec.ts
```

Expected: all operations console tests pass.

## Task 5: Full Verification And Browser Review

**Files:**
- No intended source edits unless verification finds defects.

- [ ] **Step 1: Typecheck**

Run:

```bash
cd frontend
pnpm vue-tsc --noEmit
```

Expected: exit code 0.

- [ ] **Step 2: Production build**

Run:

```bash
cd frontend
pnpm vite build
```

Expected: exit code 0. Existing Vite chunk-size warnings are acceptable.

- [ ] **Step 3: Start local frontend**

Run:

```bash
cd frontend
pnpm vite --host 127.0.0.1
```

Expected: dev server prints a localhost URL.

- [ ] **Step 4: Browser visual checks**

Open the dev server and inspect:

- `/login`
- `/dashboard`
- `/keys`
- `/admin/dashboard`
- `/admin/operations`

Check desktop and a narrow/mobile viewport if tooling supports it. Check light and dark modes. The app should look warm, full, polished, and still readable.

- [ ] **Step 5: Final status**

Report:

- Files changed.
- Tests run and results.
- Build/typecheck results.
- Visual checks performed.
- Any remaining limitations.

