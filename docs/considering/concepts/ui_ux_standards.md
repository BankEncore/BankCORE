---
status: considering
category: considering
updated: 2026-03-01
---

# BankCORE Teller UI/UX Standards (Merged Concept)

> **Status:** Considering — design governance concept. Implementation authority: [docs/current/10_phase1_spec.md](../../current/10_phase1_spec.md).

**Scope:** Teller-facing transaction workflows. **Applies to:** Deposit, Withdrawal, Transfer, Check Cashing, Draft Issuance, Bill Payment, Misc Receipt, Vault Transfer.

---

## 1. Purpose

This document defines the mandatory UI/UX interaction standards for all teller transaction screens within BankCORE Iteration 1.

These standards are control-driven. They are designed to:

- Reduce operational errors
- Support real-time transaction validation
- Preserve transaction integrity
- Enforce segregation of duties
- Align UX behavior with posting engine rules
- Maintain audit defensibility

UI behavior is considered part of the internal control environment.

---

## 2. Global Interaction Rules

- **Transaction-first UX:** Each page represents a single teller transaction in progress.
- **No mid-transaction reloads:** Editing state must persist until the teller cancels or posts.
- **Non-destructive interrupts:** Validation failures and supervisor approvals must never clear the form.
- **Progressive disclosure:** Only show fields needed for the selected transaction type and current state.
- **Dynamic line entry:** Repeating inputs use `+ Add …` (checks, splits, IDs). No fixed blank grids.
- **Real-time feedback:** Totals/subtotals, out-of-balance indicators, projected balances, and threshold warnings update live.
- **Separation of input vs reference:** Editable fields live in the entry column; reference data is read-only and visually distinct.

---

## 3. Required Screen Zones

1. **Top Context Bar (persistent):** Teller + session + branch + time
2. **Page Header:** Transaction type + state badges + primary action
3. **Entry Panel (left):** Required inputs only
4. **Reference Panel (right):** Account/party details, alerts, restrictions, projected balances
5. **Live Totals Panel:** Subtotals + balance indicator + "out of balance" delta
6. **Cash Impact Footer (persistent):** Net cash movement + projected drawer balance

---

## 4. Status Language and Visual Semantics

| State | Badge Style | Effect |
|-------|-------------|--------|
| Balanced | Success | Posting allowed |
| Out of Balance | Error | Posting disabled; show delta |
| Approval Required | Warning | Posting disabled until approved |
| Blocked | Error | Posting prohibited |

---

## 5. Supervisor Approval Standard

- Triggered from validation or real-time thresholds.
- Presented as **modal or inline panel**.
- Approve/deny does not discard data.
- Approval metadata is attached to the transaction.

---

## 6. DaisyUI Component Standards

- **Cards:** Entry `bg-base-100`, Reference `bg-base-200`, Summary `bg-base-100`
- **Money fields:** Right-aligned, tabular numbers, decimal input mode, no currency symbol in input

---

## 7. Prohibited Behaviors

- Clear form due to validation
- Modify posted transactions
- Allow posting while out of balance
- Hide projected balance impact or cash movement impact
- Allow silent supervisor overrides
- Require fixed row counts for dynamic inputs

---

## 8. Acceptance Checklist

- [ ] Uses required layout zones
- [ ] Progressive disclosure applied
- [ ] Dynamic line entry implemented
- [ ] Live totals functioning
- [ ] Out-of-balance indicator correct
- [ ] Projected balances update live
- [ ] Cash impact visible
- [ ] Approval non-destructive
- [ ] No destructive resets
- [ ] State badges accurate

---

*Merged from `11_ui_ux_standards_concept.md` and `14_teller_ui_ux_standards_concept.md` (2026-03-01).*
