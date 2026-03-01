## BankCORE Theme Mapping to UI Contract Primitives — v0.1 (DROP-IN SAFE)

This assumes you’re using (or are willing to standardize on) the primitives you referenced earlier:
`ui-panel`, `ui-panel-pad`, `ui-section-title`, `ui-muted`, `ui-money`.


> **Implementation note:** The shared partials `shared/ui/_panel.html.erb` and `shared/ui/_kv_row.html.erb` are **not implemented**. Use the Tailwind classes directly in markup as shown in the canonical markup examples below.

### 1) Add a single “UI contract” stylesheet

Create:

* `app/assets/stylesheets/ui_contract.css`

```css
/* ui_contract.css
   BankCORE workstation primitives mapped to DaisyUI theme tokens.
   Intentionally conservative: structure comes from neutrals + borders.
*/

/* Panels */
.ui-panel {
  /* DaisyUI tokens via Tailwind classes applied in markup
     Keep this class purely for semantic grouping or minor overrides. */
}

.ui-panel-pad {
  /* use Tailwind in markup: p-3 md:p-4 */
}

/* Section titles / muted */
.ui-section-title {
  /* use Tailwind in markup:
     text-xs font-semibold uppercase tracking-wide text-base-content/70 */
}

.ui-muted {
  /* use Tailwind in markup: text-xs text-base-content/60 */
}

/* Key/Value rows */
.ui-kv {
  /* container helper (optional) */
}

.ui-kv-row {
  /* use Tailwind in markup: flex items-center justify-between py-1 gap-3 */
}

.ui-kv-key {
  /* use Tailwind in markup: text-xs font-semibold uppercase tracking-wide text-base-content/60 */
}

.ui-kv-value {
  /* use Tailwind in markup: text-sm font-medium */
}

.ui-money {
  font-variant-numeric: tabular-nums;
}

/* Prevent accidental “accent wash” in reference panels */
.ui-reference-panel .badge,
.ui-reference-panel .btn-primary {
  /* Don’t hard-disable; just discourage.
     Prefer btn-outline/ghost and neutral badges in read-only panels. */
}
```

Add it to your asset pipeline the same way you include other app styles (e.g., via `app/assets/stylesheets/application.css` or your existing `app.css` entrypoint), depending on how your Rails asset setup is wired.

---

## 2) Canonical markup for primitives (use these everywhere)

### 2.1 Panel (default)

```erb
<div class="ui-panel bg-base-100 border border-base-300 rounded-box ui-panel-pad p-3 md:p-4">
  ...
</div>
```

### 2.2 Panel header row

```erb
<div class="flex items-center justify-between gap-3">
  <div class="ui-section-title text-xs font-semibold uppercase tracking-wide text-base-content/70">
    Section Title
  </div>

  <div class="flex items-center gap-2">
    <button class="btn btn-sm btn-ghost">Action</button>
    <button class="btn btn-sm btn-outline">Secondary</button>
    <button class="btn btn-sm btn-primary">Primary</button>
  </div>
</div>
```

### 2.3 Divider (default)

```erb
<div class="divider my-2"></div>
```

### 2.4 Key/Value row (reference panel)

```erb
<div class="ui-kv-row flex items-center justify-between py-1 gap-3">
  <div class="ui-kv-key text-xs font-semibold uppercase tracking-wide text-base-content/60">
    Available
  </div>
  <div class="ui-kv-value text-sm font-medium ui-money tabular-nums">
    $4,100.00
  </div>
</div>
```

---

## 3) Reference panel “no accent by default” rule (practical enforcement)

**Rule:** Right-column read-only panels use **neutral** styling; accents are for state only.

Use these defaults inside reference/totals panels:

* Buttons: `btn-sm btn-ghost` or `btn-sm btn-outline` (not `btn-primary`)
* Badges: `badge badge-sm` (neutral) unless the badge reflects a true warning/error state
* Links: `link` or `link-hover` (not accent-washed buttons)

---

## 4) Two “drop-in safe” partials to enforce consistency

### 4.1 `app/views/shared/ui/_panel.html.erb`

```erb
<%# locals: title: (string), actions: (erb block optional), body: (erb block required) %>
<div class="ui-panel bg-base-100 border border-base-300 rounded-box p-3 md:p-4">
  <% if local_assigns[:title].present? || block_given? %>
    <div class="flex items-center justify-between gap-3">
      <% if local_assigns[:title].present? %>
        <div class="ui-section-title text-xs font-semibold uppercase tracking-wide text-base-content/70">
          <%= title %>
        </div>
      <% end %>

      <%# actions slot %>
      <% if local_assigns[:actions].present? %>
        <div class="flex items-center gap-2">
          <%= actions %>
        </div>
      <% end %>
    </div>

    <div class="divider my-2"></div>
  <% end %>

  <%= yield %>
</div>
```

Usage:

```erb
<%= render "shared/ui/panel", title: "Account Reference", actions: capture do %>
  <button class="btn btn-sm btn-ghost">Refresh</button>
<% end do %>
  <!-- body -->
<% end %>
```

### 4.2 `app/views/shared/ui/_kv_row.html.erb`

```erb
<%# locals: k:, v:, v_class: (optional) %>
<div class="ui-kv-row flex items-center justify-between py-1 gap-3">
  <div class="ui-kv-key text-xs font-semibold uppercase tracking-wide text-base-content/60">
    <%= k %>
  </div>
  <div class="ui-kv-value text-sm font-medium <%= local_assigns[:v_class] %>">
    <%= v %>
  </div>
</div>
```

Usage:

```erb
<%= render "shared/ui/kv_row", k: "Ledger", v: number_to_currency(@ledger), v_class: "ui-money tabular-nums" %>
```

---

## 5) Theme activation (bankcore-light / bankcore-dark)

If you want to lock the Teller shell to light mode initially (common in branch environments):

```erb
<html data-theme="bankcore-light">
```

Or if you already toggle themes, ensure your toggle only outputs:

* `bankcore-light`
* `bankcore-dark`

---

## 6) PR review “Banking feel” checklist (mechanical)

* [ ] Reference/totals panels do **not** use `btn-primary` unless state/action requires it
* [ ] `border-base-300` is present on workstation panels
* [ ] `divider my-2` or `border-t border-base-200 my-2` used for section separation
* [ ] Monetary values use `tabular-nums` and are right-aligned where appropriate
* [ ] The only prominent `btn-primary` on a screen is the commit action (Post/Submit/Confirm)

---
