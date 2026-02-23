## DaisyUI Theme Override (Banking / Workstation) — v0.1 (DROP-IN SAFE)

This gives you a **conservative, high-contrast, low-saturation** theme with restrained accents and “institutional” neutrals. It is designed to feel like a teller/workstation UI (not a consumer app).

### 1) `tailwind.config.js` (or `tailwind.config.ts`) DaisyUI override

```js
// tailwind.config.js
module.exports = {
  content: [
    "./app/views/**/*.html.erb",
    "./app/helpers/**/*.rb",
    "./app/javascript/**/*.js",
    "./app/assets/stylesheets/**/*.css",
  ],
  theme: { extend: {} },
  plugins: [require("daisyui")],

  daisyui: {
    styled: true,
    base: true,
    utils: true,
    logs: false,
    themes: [
      {
        "bankcore-light": {
          // ----- Core surfaces -----
          "base-100": "#FFFFFF",
          "base-200": "#F5F7FA", // subtle panel background option
          "base-300": "#E3E8EF", // borders/dividers

          // ----- Text / neutrals -----
          "base-content": "#111827", // slate/ink
          "neutral": "#1F2937",       // deep neutral for nav / headers
          "neutral-content": "#F9FAFB",

          // ----- Brand / action colors (restrained) -----
          "primary": "#0B2D5B",            // institutional navy
          "primary-content": "#FFFFFF",

          "secondary": "#334155",          // slate
          "secondary-content": "#FFFFFF",

          "accent": "#0E7490",             // muted teal (sparingly)
          "accent-content": "#FFFFFF",

          // ----- State colors (clear, not neon) -----
          "info": "#1D4ED8",
          "info-content": "#FFFFFF",

          "success": "#166534",
          "success-content": "#FFFFFF",

          "warning": "#92400E",
          "warning-content": "#FFFFFF",

          "error": "#991B1B",
          "error-content": "#FFFFFF",

          // ----- UI density / shape tokens -----
          "--rounded-box": "0.4rem",    // panels (conservative)
          "--rounded-btn": "0.35rem",   // buttons
          "--rounded-badge": "0.25rem", // badges
          "--border-btn": "1px",
          "--tab-border": "1px",
          "--tab-radius": "0.35rem",

          // Typography (keep normal weight; banking UI feels heavier if over-bolded)
          "--btn-text-case": "none",    // avoid all-caps buttons
        },
      },
      {
        "bankcore-dark": {
          // ----- Core surfaces -----
          "base-100": "#0B1220", // deep ink
          "base-200": "#0F1A2E",
          "base-300": "#1F2A44",

          // ----- Text / neutrals -----
          "base-content": "#E5E7EB",
          "neutral": "#0A1020",
          "neutral-content": "#E5E7EB",

          // ----- Brand / action colors -----
          "primary": "#7AA2FF",          // readable on dark
          "primary-content": "#0B1220",

          "secondary": "#94A3B8",
          "secondary-content": "#0B1220",

          "accent": "#5EEAD4",           // still restrained; watch overuse
          "accent-content": "#042F2E",

          // ----- State colors -----
          "info": "#60A5FA",
          "info-content": "#0B1220",

          "success": "#4ADE80",
          "success-content": "#052E16",

          "warning": "#FBBF24",
          "warning-content": "#1F1300",

          "error": "#F87171",
          "error-content": "#2A0A0A",

          // ----- UI density / shape tokens -----
          "--rounded-box": "0.4rem",
          "--rounded-btn": "0.35rem",
          "--rounded-badge": "0.25rem",
          "--border-btn": "1px",
          "--tab-border": "1px",
          "--tab-radius": "0.35rem",
          "--btn-text-case": "none",
        },
      },
    ],
  },
};
```

---

## 2) Set the active theme

### Option A (simple): set `data-theme` on `<html>`

```erb
<!-- app/views/layouts/application.html.erb -->
<html data-theme="bankcore-light">
```

### Option B (supports toggling): bind `data-theme` dynamically

If you already have a theme toggle mechanism, just ensure the values used are:

* `bankcore-light`
* `bankcore-dark`

---

## 3) “Banking tuning” conventions this theme expects (so it actually feels right)

* Use **neutrals and borders** as the primary structure: `border-base-300`, `bg-base-100`
* Use `btn-primary` only for the *single* “commit” action on a screen (Post / Submit / Confirm)
* Use `btn-outline` / `btn-ghost` for everything else
* Use `warning/error` only for state (holds, blocks, mismatches), not decoration
* Default to small controls (`btn-sm`, `input-sm`, etc.) per your density standard

---

## 4) Optional: Make outlines and borders feel more “ledger-like” (DROP-IN SAFE)

If you want slightly stronger borders across the app without changing every class, add this to a global stylesheet:

```css
/* app/assets/stylesheets/bankcore_theme_overrides.css */
:root [data-theme="bankcore-light"] .ui-panel,
:root [data-theme="bankcore-light"] .card {
  border-width: 1px;
}

:root [data-theme="bankcore-dark"] .ui-panel,
:root [data-theme="bankcore-dark"] .card {
  border-width: 1px;
}
```

(Only do this if you already rely on `.ui-panel` / `.card` consistently.)
