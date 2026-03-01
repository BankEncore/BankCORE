
# BankCORE UI Density Standard (Workstation) — v0.1

This document defines the default sizing, spacing, and layout patterns for BankCORE’s Teller/Workstation UI.
Primary objectives: compact density, predictable structure, audit-friendly readability.

---

## 1. Principles

- **Workstation-first:** procedural layouts, not marketing UI.
- **Compact by default:** reduce wasted vertical space; keep key info visible.
- **Consistent structure:** same patterns for panels, headers, actions, and key/value rows.
- **Audit readability:** labels are explicit; numbers align; meaning is not color-dependent.

---

## 2. Global Defaults

### 2.1 Typography

- Page title: `text-xl font-semibold`
- Section title: `text-xs font-semibold uppercase tracking-wide text-base-content/70`
- Body text: `text-sm`
- Muted/help: `text-xs text-base-content/60`
- Numbers/money: `tabular-nums` (typically with `text-right`)

### 2.2 Spacing Defaults

| Use | Default |
|---|---|
| Panel padding | `p-3` (tight) / `p-4` (normal) |
| Stack spacing | `space-y-2` (tight) / `space-y-3` (normal) |
| Grid gaps | `gap-2` (tight) / `gap-3` (normal) |
| Section separation | `divider my-2` or `border-t border-base-200 my-2` |
| Table cell padding | `px-2 py-1` |

Avoid by default: `p-6`, `gap-6`, `space-y-6`, oversized headers.

---

## 3. DaisyUI Component Sizing

Default to **small** components unless an exception is documented.

### 3.1 Inputs

- Text: `input input-bordered input-sm`
- Select: `select select-bordered select-sm`
- Textarea: `textarea textarea-bordered textarea-sm` (rare in teller workflow)
- Money/amount: add `text-right tabular-nums`

### 3.2 Buttons

- Primary: `btn btn-sm btn-primary`
- Secondary: `btn btn-sm btn-outline`
- Utility: `btn btn-sm btn-ghost`
- Destructive: `btn btn-sm btn-error` (sparingly)

### 3.3 Badges

- `badge badge-sm`
- Use semantic color sparingly and consistently (e.g., holds, blocks, risk flags).

---

## 4. Layout Patterns

### 4.1 Panels (preferred over “cards”)

Panel container:
- `bg-base-100 border border-base-300 rounded-box`
- Padding: `p-3` or `p-4`

Panel header pattern:
- Left: section title
- Right: compact actions (`btn-sm`)

### 4.2 Forms

- Use 2-column grids where practical:
  - `grid grid-cols-1 md:grid-cols-2 gap-3`
- Labels are required; do not rely on placeholder-only forms.
- Helper text is muted `text-xs`.

### 4.3 Tables / Lists

- Use dense tables by default:
  - `table table-sm`
- Monetary columns:
  - `text-right tabular-nums`
- Row actions should be compact and right-aligned.

---

## 5. Right-Column Reference Panels

Reference/totals panels are read-only and must remain information-dense.

- Keys: `text-xs font-semibold uppercase tracking-wide text-base-content/60`
- Values: `text-sm font-medium tabular-nums`
- Prefer short key/value rows with separators over large blocks.

---

## 6. Do / Don’t

### Do
- Default to `*-sm` components
- Use `tabular-nums` for amounts/totals/balances
- Keep action bars consistent and short
- Use separators to communicate structure (ledger-like)

### Don’t
- Don’t use large cards or roomy marketing spacing
- Don’t use color as the primary signal
- Don’t hide critical fields behind expanding UI in teller flows
- Don’t mix sizes (`btn-lg` next to `input-sm`) without a reason

---

## 7. Canonical Class Aliases (recommended)

These reduce repetition and enforce consistency.

- `.ui-panel` → `bg-base-100 border border-base-300 rounded-box`
- `.ui-panel-pad` → `p-3 md:p-4`
- `.ui-section-title` → `text-xs font-semibold uppercase tracking-wide text-base-content/70`
- `.ui-muted` → `text-xs text-base-content/60`
- `.ui-money` → `text-right tabular-nums`

---

## 8. Reference Snippets

### 8.1 Compact Panel + Two-Column Inputs

```erb
<div class="ui-panel ui-panel-pad">
  <div class="flex items-center justify-between">
    <div class="ui-section-title">Transaction Entry</div>
    <div class="flex gap-2">
      <button class="btn btn-sm btn-ghost">Clear</button>
      <button class="btn btn-sm btn-primary">Post</button>
    </div>
  </div>

  <div class="divider my-2"></div>

  <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
    <label class="form-control">
      <div class="label py-0"><span class="label-text ui-muted">Account</span></div>
      <input class="input input-bordered input-sm" placeholder="Search name / account #" />
    </label>

    <label class="form-control">
      <div class="label py-0"><span class="label-text ui-muted">Cash Amount</span></div>
      <input class="input input-bordered input-sm ui-money" inputmode="decimal" placeholder="0.00" />
    </label>
  </div>
</div>
````

### 8.2 Key/Value Row (Reference Panel)

```erb
<div class="flex items-center justify-between py-1">
  <div class="text-xs font-semibold uppercase tracking-wide text-base-content/60">Available</div>
  <div class="text-sm font-medium tabular-nums">$4,100.00</div>
</div>
```

## Spacing Rules (Workstation Density)

This app uses a constrained spacing profile to keep screens compact and consistent.

### Allowed spacing tokens (default set)
Use only these Tailwind spacing values unless a layout explicitly requires otherwise:

- `0`, `0.5`, `1`, `1.5`, `2`, `3`, `4`, `6`, `8`

Avoid by default: `5`, `7`, `10+`, `p-6`, `gap-6`, `space-y-6`.

### Spacing roles (reviewable intent mapping)

| Role | Token | Use |
|---|---:|---|
| Micro | `1` | icon/text separation, tiny inline gaps |
| Tight | `2` | default compact spacing, dense row padding |
| Default | `3` | standard grid gaps, panel internals |
| Comfort | `4` | normal panel padding, slightly larger blocks |
| Section | `6` | page section separation (rare) |
| Page | `8` | top-level layout separation (rare) |

### Canonical defaults by primitive

#### Panels
- Container: `bg-base-100 border border-base-300 rounded-box`
- Padding: `p-3` (tight default) or `p-4` (normal)
- Internal stacks: `space-y-2` (tight) or `space-y-3` (default)
- Panel-to-panel separation: `mt-3`

#### Forms
- 2-col grid gap: `gap-3`
- Vertical stacking: `space-y-3` when not using a grid
- Helper text spacing: `mt-1`
- Monetary fields: add `text-right tabular-nums`

#### Tables / dense rows
- Table: `table table-sm`
- Cells: `px-2 py-1`
- Group separation: `mt-2`

#### Read-only key/value panels (reference/totals)
- Row padding: `py-1`
- Section separator: `my-2` (divider or border)

#### Action rows
- Button gap: `gap-2`
- Separation from content: `mt-2` (tight) or `mt-3` (default)

#### Dividers / separators
- Default: `my-2`
- Use `my-3` only when visually necessary

### PR review checklist (mechanical)
- [ ] Uses only approved spacing tokens (`0–4`, `6`, `8`) unless justified
- [ ] Panels use `p-3` or `p-4` (not `p-6`)
- [ ] Grids use `gap-2` or `gap-3` (not `gap-6`)
- [ ] Dense rows use `py-1` or `py-2` (not `py-4`)
- [ ] Dividers use `my-2` by default
- [ ] Button groups use `gap-2`
```

---

## DROP-IN SAFE: Minimal “Spacing Exceptions” comment pattern

Use this when you must break the profile:

```erb
<%# SPACING EXCEPTION: Using mt-6 to separate unrelated workflow sections on this page (reviewed) %>
```
