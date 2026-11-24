---
name: solid-admin-ux
description: >-
  Guides visual identity, design tokens, layout architecture, microcopy, and
  interactive HTML prototyping for ateng-solid admin interfaces. Use when
  designing the ateng-solid design system, drafting PRD interaction specs,
  generating multi-variant UI prototypes, or auditing admin pages for UX,
  accessibility, and anti-template quality.
---

# Solid Admin UX & Prototyping

Design a distinctive, disciplined enterprise admin identity for `ateng-solid`—never falling back to generic "AI slop" templates or `theme-pro.css` defaults when redefining the upper-layer look, while preserving `@atengk/core` and `@atengk/vue` headless guarantees.

## Architecture Contract (What Changes vs. What Stays)

- **Free to redesign**: Color palette, typography scale, radius/elevation/border tokens, Light/Dark themes, `AdminLayout` shell geometry (sidebar/topbar/tabs/workspace), `/login` & `/dashboard` composition, and custom CSS theme sheets replacing `theme-pro.css`.
- **Must remain intact**: `@atengk/core` (`http`, Snowflake string IDs, `AuthManager`, `TenantManager`, `formatMask*`), `@atengk/vue` (`usePagination`, `useAuth`, `useTabsNav`, `useExcel`, `useIdempotent`), functional `@atengk/element-plus` contracts (`AtengQueryForm` IME/collapse, `AtengTable` tools/column persistence/batch bar, `AtengDialog`/`AtengDrawer` async form validation, `AtengExcelFeedback`), `v-permission` / `v-idempotent`, and **TailwindCSS without Preflight**.

## Workflow

Follow these steps in order; do not jump to building pages until the current step's completion criterion passes.

### 1. Define or Load the Design System (`MASTER`)

Check `docs/specs/prd/design-system.md`. If missing (or when establishing the global shell), draft it in two passes before writing any UI prototype:

1. **Draft a compact token & layout plan**:
   - **Color (4–6 semantic tokens, Light + Dark)**: Canvas, surface/card, primary accent, ink hierarchy, hairline border, and semantic status (`success`/`warning`/`danger`/`info`) mapped cleanly to `--el-*` / custom CSS variables.
   - **Typography**: Intentional font pairing (clean Chinese UI sans + geometric/humanist Latin + `tabular-nums` monospace for IDs, counts, timestamps, and IP addresses).
   - **Layout Geometry**: Structural proportions for `AdminLayout` (sidebar, header, tabs bar, content grid, drawer/dialog density) and ASCII wireframes.
   - **Restraint Principles**: One memorable signature choice; everything else quiet and content-dense.
2. **Critique against generic AI defaults**: Test whether the plan looks like a generic template (purple-indigo cliché gradients, oversized fake KPI boxes, decorative eyebrow pills, timid gray-on-gray contrast). Revise and record what changed and why before building.

*Completion criterion*: `docs/specs/prd/design-system.md` defines Light/Dark tokens, typography, layout structure, and anti-default revisions.

### 2. Align PRD Domain Rules & Microcopy

Before prototyping a page or domain:

1. Ground copy and flows in canonical domain terms (`CONTEXT-MAP.md`, `ateng-solid-admin-web/CONTEXT.md`, `.agents/rules/contracts.md`).
2. Audit every button label, field validation, empty state, and error message against [ux-and-copy-checklist.md](./references/ux-and-copy-checklist.md):
   - Specific action verbs ("保存配置" / "强退会话" / "确认删除", never vague "提交").
   - In-memory plaintext in edit forms vs. `formatMask*` in read-only tables/descriptions.
   - Actionable empty and error states (state what failed and the immediate next step).

*Completion criterion*: Domain PRD rules cover both `tenantEnabled = false` and `tenantEnabled = true` states, field validations, and every CTA/error/empty-state copy.

### 3. Prototype by Question Shape

Select the prototype shape matching what the user needs to evaluate (load `prototype` skill conventions if multi-variant):

- **Visual & Layout Questions** (`AdminLayout` shell, `/login`, `/dashboard`, theme look): Build **2–3 structurally distinct HTML variants** in a single self-contained prototype file with a floating bottom switcher (`?variant=A|B|C` + `←`/`→` keyboard support outside inputs) so structure—not just color—can be compared directly.
- **Business Logic & State Questions** (`tenantEnabled` toggle, `super_admin` tenant switch, Fesod Excel feedback flow, `@DataScope` custom dept tree, tenant package pruning): Include explicit **state visibility** and **one-click scenario walkthroughs** (happy path, validation failure, forbidden guardrails) in standalone HTML/CSS/JS requiring zero build server.

Every HTML prototype must run by directly opening the `.html` file in a browser (no Vite server required), support Light/Dark toggle + `tenantEnabled` simulation where applicable, and cite exact CSS tokens from `design-system.md`.

*Completion criterion*: Prototype opens cleanly offline in browser, exercises all planned interactive states without dead buttons, and explicitly surfaces state transitions.

### 4. Self-Critique Before Handoff

Before presenting a prototype or PRD slice, verify every item in [ux-and-copy-checklist.md](./references/ux-and-copy-checklist.md) (accessibility contrast `>= 4.5:1`, visible focus rings, tabular numbers, async loading lock, destructive-action guardrails, zero horizontal overflow, and removal of decorative noise).
