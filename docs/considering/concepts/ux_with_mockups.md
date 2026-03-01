---
status: considering
category: considering
updated: 2026-03-01
---

# BankCORE Teller UI/UX — Design Concepts and Mockups

> **Status:** Considering — conceptual. Implementation authority: [docs/current/10_phase1_spec.md](../../current/10_phase1_spec.md).

**Goal:** Make UI/UX behavior enforceable via a standard page skeleton, shared partials, and Stimulus contracts.

---

## 1. Design Philosophy

- **Transaction-centric layout:** Each screen = single transaction event; transaction type and context visible; input vs reference separated
- **Context-aware field presentation:** Only fields relevant to transaction type and workflow state
- **Progressive disclosure:** Optional/conditional inputs hidden until required
- **Dynamic reference panels:** Account/party data displays without page reload; read-only, visually distinct
- **Real-time feedback:** Subtotals, totals, cash in/out, net impact, projected balances update live
- **Out-of-balance indicators:** Visible indicator, submission disabled, imbalance amount displayed
- **Non-destructive overrides:** Approval prompts preserve state; modal or inline; never clear data

---

## 2. File and Component Inventory (Conceptual)

### Rails views

```
app/views/teller/
  deposits/new.html.erb, withdrawals/new.html.erb, transfers/new.html.erb,
  check_cashing/new.html.erb, drafts/new.html.erb, bill_payments/new.html.erb,
  misc_receipts/new.html.erb, vault_transfers/new.html.erb
```

### Shared partials (conceptual)

```
app/views/teller/shared/
  _topbar.html.erb, _page_header.html.erb, _reference_panel.html.erb,
  _totals_panel.html.erb, _cash_footer.html.erb, _approval_modal.html.erb,
  _line_item_container.html.erb, _errors_banner.html.erb
```

---

## 3. Required Layout Zones

1. **Topbar (persistent)** – session context
2. **Page Header** – transaction name + state badges + actions
3. **Main Grid** – left entry + right reference panel
4. **Line Items Area** – dynamic rows (checks, splits, etc.)
5. **Totals Panel** – live calculations + out-of-balance indicator
6. **Cash Footer** – net cash movement + projected drawer

---

## 4. Stimulus Controller Contracts (Conceptual)

- **teller_tx_controller** — orchestrator; post gating; listens to tx:recalc, tx:balance_changed, tx:approval_*
- **line_items_controller** — add/remove rows; emits tx:recalc
- **totals_controller** — live math; must match posting engine rules
- **reference_panel_controller** — read-only account/party; updates on tx:recalc
- **approval_modal_controller** — non-destructive interrupt; approval metadata

---

## 5. Wireframe Concept — Deposit Screen

```
┌──────────────────────────────────────────────────────────────────────────┐
│ BANKCORE   Teller: T001  Session: S045  Branch: 001  03/18/2026 10:42 AM │
└──────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────┬──────────────────────────────────────┐
│ TRANSACTION ENTRY                │ ACCOUNT REFERENCE (Read-Only)        │
│ Account [Search...]               │ Thomas Miller ****1234               │
│ Cash Amount [500.00]             │ Ledger: $4,250  Available: $4,100    │
│ CHECKS [ + Add Check ]           │ Projected: $4,750 / $4,600            │
└─────────────────────────────────┴──────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────────┐
│ TRANSACTION SUMMARY   Cash: $500  Checks: $250  TOTAL: $750  ✔ Balanced  │
└──────────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────────┐
│ DRAWER STATUS   Net: +$500  Projected: $12,930                           │
└──────────────────────────────────────────────────────────────────────────┘
```

---

## 6. Acceptance Checklist

- [ ] Uses shared topbar, page_header, totals_panel, cash_footer
- [ ] Reference panel read-only and visually distinct
- [ ] No page reload during active entry
- [ ] Progressive disclosure; no fixed blank grids
- [ ] "+ Add" for line items; unlimited rows; remove works
- [ ] Totals update on every change; out-of-balance visible; Post disabled when invalid
- [ ] Approval modal preserves state
- [ ] Blocking errors prevent post; no destructive resets

---

*Merged from `21_ux_with_mockups_concept.md` and `22_teller_ui_dev_concept.md.md` (2026-03-01).*
