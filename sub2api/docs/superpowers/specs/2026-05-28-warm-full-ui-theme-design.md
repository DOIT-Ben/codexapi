# Warm Full UI Theme Design

## Background

The current frontend uses a cool teal primary palette and lightweight SaaS dashboard styling. The target direction is a warmer, fuller, more branded API gateway experience inspired by NexaHub AI, without copying its logo, exact layout, or proprietary identity.

This is a visual and interaction polish pass. It must not change API behavior, routing, authentication, billing logic, usage accounting, upstream provider logic, or admin permissions.

## Goals

- Make the product feel like a mature commercial API gateway rather than a default open-source admin panel.
- Move the visual language from cool teal to warm clay-orange, cream, and deep brown.
- Make buttons, cards, badges, inputs, sidebar active states, and dashboard statistic surfaces feel fuller and more tactile.
- Keep the interface usable for repeated operational work: dense enough for admins, clear enough for beginner users.
- Preserve the existing component class system so the change remains low risk and broad pages inherit the new theme automatically.

## Non-Goals

- Do not clone NexaHub AI exactly.
- Do not change the logo asset unless a separate branding task approves it.
- Do not redesign all pages one by one in this pass.
- Do not introduce a new UI framework.
- Do not replace Tailwind or the current global utility/component classes.
- Do not change payment, registration, channel, user, or API-key behavior.

## Target Visual Direction

The theme should be close to NexaHub's warm and full feeling, while remaining distinct.

### Palette

Use a warm commercial palette:

- Primary clay orange: `#e48556`
- Primary deep clay: `#c96442`
- Strong text brown: `#3a332a`
- Muted text taupe: `#8a8174`
- Warm border: `#e4dacb`
- Soft page background: `#f7f2ea`
- Elevated card background: `#fffaf4`
- Dark-mode primary should remain warm but readable, using lighter amber-orange highlights on dark surfaces.

Status colors should not all become orange. Keep semantic colors recognizable:

- Success: emerald/green
- Warning: amber
- Danger: red
- Info/primary: clay-orange

### Shape And Density

- Keep rounded UI, but avoid making operational tables feel toy-like.
- Buttons should feel full: slightly taller, clear gradient or solid fill, soft warm shadow, active press state.
- Cards should feel elevated: warm border, soft shadow, optional subtle top highlight.
- Inputs should feel aligned with cards: warm border, cream/white fill, orange focus ring.
- Badges should be pill-shaped and readable, with stronger contrast than the current light teal tags.

## Implementation Approach

Use a layered implementation so the theme can ship safely.

### Layer 1: Theme Tokens

Files:

- `frontend/tailwind.config.js`
- `frontend/src/style.css`

Changes:

- Replace the `primary` color scale from teal to warm clay-orange.
- Update shadow tokens such as `glow`, `glow-lg`, `card`, and `card-hover` to use warm orange/brown shadows.
- Update background gradients such as `gradient-primary` and `mesh-gradient`.
- Add or adjust warm surface classes through existing `.card`, `.glass`, `.glass-card`, `.input`, `.badge-*`, `.btn-*` definitions.

Expected result:

- Most existing pages inherit the new brand feeling without page-level rewrites.

### Layer 2: Core Shell

Files:

- `frontend/src/components/layout/AppLayout.vue`
- `frontend/src/components/layout/AppHeader.vue`
- `frontend/src/components/layout/AppSidebar.vue`
- Existing global sidebar classes in `frontend/src/style.css`

Changes:

- Change the app background from cool gray to soft warm background.
- Keep the mesh background subtle; it must not dominate operational screens.
- Sidebar should feel premium:
  - Warm white/cream surface in light mode.
  - Deep warm dark surface in dark mode.
  - Active nav item uses clay-orange fill, border, and icon/text color.
  - Hover state uses warm tint, not cold gray.
- Header should stay glass-like but use warm translucent white and warm border.
- Balance pill and avatar gradient should use the warm primary palette.

Expected result:

- First impression changes immediately after login.
- Sidebar and header match the new brand.

### Layer 3: High-Visibility User Surfaces

Files:

- `frontend/src/views/user/DashboardView.vue`
- `frontend/src/views/user/KeysView.vue`
- `frontend/src/views/user/UsageView.vue`
- Shared classes already used by these pages.

Changes:

- Prefer global class inheritance first.
- Only add page-level refinements where current markup looks flat after token changes.
- The user dashboard should emphasize:
  - Balance
  - API key access
  - API endpoint / docs access
  - Today's usage
  - Recent usage trend
- Avoid marketing-style hero sections inside the app. This is a working dashboard.

Expected result:

- Beginner users can quickly understand where to copy API information and where to see cost/usage.

### Layer 4: High-Visibility Admin Surfaces

Files:

- `frontend/src/views/admin/DashboardView.vue`
- `frontend/src/views/admin/OperationsConsoleView.vue`
- Existing table/card components used by admin pages.

Changes:

- Admin cards should remain scan-friendly.
- Operational warning and danger states must keep semantic colors.
- The new warm theme should support dense data and not reduce readability.
- Operations console should retain emphasis on abnormal requests, provider status, rate limits, and capacity signals.

Expected result:

- Admin pages feel branded but still operationally serious.

### Layer 5: Auth Pages

Files:

- `frontend/src/components/layout/AuthLayout.vue`
- `frontend/src/views/auth/LoginView.vue`
- `frontend/src/views/auth/RegisterView.vue`

Changes:

- Auth pages should use the warm brand feeling more strongly than inner dashboards.
- Keep the form centered and efficient.
- Login/register buttons use the warm primary style.
- Do not add large marketing copy blocks unless the page already has a matching content slot.

Expected result:

- First-time users see a polished commercial platform entrance.

## Component Rules

### Buttons

Global `.btn` behavior remains:

- Inline-flex, icon-friendly.
- 200ms transition.
- Focus ring.
- Disabled state.
- Active press scale.

Theme changes:

- `.btn-primary`: warm orange gradient, white text, warm shadow.
- `.btn-secondary`: cream/white background, warm border, dark brown text.
- `.btn-ghost`: warm hover tint.
- Danger/success/warning keep semantic color families.

### Cards

Global `.card` should become the default warm elevated surface:

- Light mode: near-white or warm white.
- Dark mode: existing dark surface, slightly warmed if feasible.
- Border: warm neutral.
- Shadow: soft brown/orange cast.
- Hover: slight lift only for interactive cards.

Nested card anti-pattern remains discouraged. Use cards for repeated items, modals, and framed tools, not page sections inside page sections.

### Inputs

Inputs should be comfortable and clear:

- Warm neutral border.
- Cream/white fill.
- Orange focus border and focus ring.
- Error state remains red.

### Badges

Badges should be readable and categorical:

- Primary badge: warm orange tint.
- Gray badge: warm neutral tint.
- Success/warning/danger remain semantic.

### Tables

Tables should not become visually heavy:

- Header background can be warm-tinted but low contrast.
- Row hover uses a subtle warm tint.
- Borders should remain light and clear.

## Accessibility And UX Constraints

- Maintain readable contrast for text, buttons, and badges.
- Do not rely on color alone for danger, warning, or success states.
- Keep keyboard focus visible.
- Do not reduce table density so much that admin work becomes slower.
- Do not introduce animations that distract from operational workflows.
- Mobile layout must remain usable with sidebar collapsed/hidden.
- Text must not overflow buttons, badges, cards, or sidebar labels.

## File-Level Plan

Primary files:

- `frontend/tailwind.config.js`
- `frontend/src/style.css`
- `frontend/src/components/layout/AppLayout.vue`
- `frontend/src/components/layout/AppHeader.vue`
- `frontend/src/components/layout/AppSidebar.vue`
- `frontend/src/components/layout/AuthLayout.vue`

Likely page refinements:

- `frontend/src/views/user/DashboardView.vue`
- `frontend/src/views/user/KeysView.vue`
- `frontend/src/views/admin/DashboardView.vue`
- `frontend/src/views/admin/OperationsConsoleView.vue`

Tests to inspect/update if snapshots or source assertions depend on CSS:

- `frontend/src/components/layout/__tests__/AppSidebar.spec.ts`
- `frontend/src/views/admin/__tests__/OperationsConsoleView.spec.ts`
- Existing dashboard or auth tests if class-based assertions fail.

## Verification Plan

Run automated checks:

```bash
cd frontend
pnpm vitest --run src/components/layout/__tests__/AppSidebar.spec.ts src/views/admin/__tests__/OperationsConsoleView.spec.ts
pnpm vue-tsc --noEmit
pnpm vite build
```

Run browser checks after implementation:

- Login page desktop and mobile.
- User dashboard desktop and mobile.
- API keys page desktop.
- Admin dashboard desktop.
- Operations console desktop.
- Dark mode toggle.
- Sidebar expanded and collapsed.

Visual acceptance criteria:

- The app immediately reads as warm, polished, and commercial.
- Primary buttons feel full and clickable.
- Cards have clearer depth without becoming noisy.
- Sidebar selected state is unmistakable.
- Tables remain easy to scan.
- Dark mode remains usable and does not look like a broken light theme inversion.

## Rollout And Risk

This is a frontend-only visual change. The main risks are:

- Too much orange, making all states look the same.
- Reduced contrast on warm backgrounds.
- Hidden regressions in dark mode.
- Sidebar spacing or collapsed labels breaking.
- Build/test failures from class changes in tests.

Mitigation:

- Keep semantic status colors.
- Change global tokens first, then inspect pages before page-level edits.
- Verify both light and dark mode.
- Keep layout dimensions stable.
- Avoid broad markup refactors.

## Approval Gate

Implementation should start only after this design is approved.
