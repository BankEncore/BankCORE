# BankCORE

# Teller UI/UX Standards

```
docs/ui-ux-standards-teller.md
```

## Iteration 1 — Teller Operations Platform

**Status:** Conceptual (Design Governance) **Scope:** Teller-facing transaction workflows only **Applies To:** Deposit, Withdrawal, Transfer, Check Cashing, Draft Issuance, Bill Payment, Misc Receipt, Vault Transfer

---

# 1\. Purpose

This document defines the mandatory UI/UX interaction standards for all teller transaction screens within BankCORE Iteration 1\.

These standards are control-driven. They are designed to:

* Reduce operational errors  
* Support real-time transaction validation  
* Preserve transaction integrity  
* Enforce segregation of duties  
* Align UX behavior with posting engine rules  
* Maintain audit defensibility

UI behavior is considered part of the internal control environment.

---

# 2\. Core Design Principles

## 2.1 Transaction-Centric Design

Each teller screen represents a single transaction container.

The UI must clearly display:

* Transaction type  
* Teller/session context  
* Transaction state (Balanced / Approval Required / Out of Balance)  
* Primary action (Post/Complete)

No multi-transaction editing on a single screen.

---

## 2.2 No Mid-Transaction Reloads

During transaction editing:

* No page reloads  
* No redirect resets  
* No destructive validation

All interruptions (errors, approvals) must preserve state.

---

## 2.3 Progressive Disclosure

The UI shall display only fields required for the selected transaction type and current state.

Examples:

* Check entry fields appear only when checks are added.  
* Hold fields appear only when hold is expanded.  
* Mixed disbursement fields appear only when selected.  
* Supervisor credentials appear only when required.

Unused fields must not be visible.

---

## 2.4 Dynamic Line Entry

For repeatable inputs (checks, disbursement splits, ID entries):

* Use a `+ Add` control.  
* Do not pre-render fixed empty rows.  
* Allow unlimited entries.  
* Allow removal of individual items.  
* Update totals immediately on add/remove/change.

---

## 2.5 Real-Time Feedback (Mandatory)

The UI must update instantly (without submission):

* Subtotals  
* Transaction total  
* Cash in/out amounts  
* Net cash movement  
* Out-of-balance indicator  
* Projected ledger balance  
* Projected available balance  
* Threshold warnings

The “Post” button must be disabled if:

* Out of balance  
* Required fields missing  
* Supervisor approval pending  
* Blocking validation error present

---

## 2.6 Non-Destructive Supervisor Escalation

If approval is required:

* Display modal or inline approval panel.  
* Do not clear form.  
* Do not reset dynamic rows.  
* Do not lose calculated totals.  
* Deny returns to editing.  
* Approve resumes posting path.

Approval metadata must be attached to transaction.

---

# 3\. Required Screen Structure

All teller transaction pages must contain the following zones:

---

## 3.1 Top Context Bar (Persistent)

Displays:

* Teller ID  
* Session ID  
* Branch  
* Timestamp

Must remain visible during transaction.

---

## 3.2 Page Header

Displays:

* Transaction type  
* State badge(s)  
* Primary action button  
* Cancel option

State badges:

| State | Badge Style |
| :---- | :---- |
| Balanced | Success |
| Approval Required | Warning |
| Out of Balance | Error |
| Blocked | Error |

---

## 3.3 Entry Panel (Left Column)

Contains:

* Editable transaction inputs  
* Progressive disclosure sections  
* Dynamic line items

Must not contain:

* Read-only account balances  
* Audit data  
* Posting engine internals

---

## 3.4 Reference Panel (Right Column)

Read-only display of:

* Account title  
* Account status  
* Ledger balance  
* Available balance  
* Projected balances  
* Alerts  
* Restrictions

Must be visually distinct from editable fields.

---

## 3.5 Live Totals Panel

Displays:

* Subtotals (cash, checks, fees, etc.)  
* Total transaction amount  
* Out-of-balance delta (if applicable)  
* Balanced indicator

Out-of-balance must:

* Display delta amount  
* Visually emphasize error  
* Disable primary action

---

## 3.6 Cash Impact Footer

Displays:

* Net cash movement  
* Projected drawer balance

Must be visible before posting.

No transaction involving cash may be posted without visible cash impact preview.

---

# 4\. Validation Model

Validation must occur:

* On field change  
* On line item add/remove  
* On submission attempt

Validation categories:

| Category | Effect |
| :---- | :---- |
| Blocking Error | Prevent posting |
| Warning | Allow posting |
| Approval Required | Require supervisor |
| Informational | Display only |

Validation must not clear entered data.

---

# 5\. Visual & Component Standards (DaisyUI)

## Cards

* Entry: `bg-base-100`  
* Reference: `bg-base-200`  
* Summary: `bg-base-100`

## Alerts

* Error: `alert-error`  
* Warning: `alert-warning`  
* Info: `alert-info`

## Badges

* Success: Balanced  
* Warning: Approval Required  
* Error: Out of Balance / Blocked

## Money Fields

* Right-aligned  
* Tabular numbers  
* Decimal input mode  
* No currency symbol inside input

---

# 6\. Transaction-Specific Requirements

---

## 6.1 Deposit

Must include:

* Account selection  
* Cash amount  
* Dynamic checks  
* Optional hold per check  
* Immediate availability breakdown (if holds present)

---

## 6.2 Withdrawal (Mixed Disbursement)

Must include:

* Account selection  
* Withdrawal amount  
* Disbursement method selection  
* Progressive display of split fields  
* Fee handling  
* Account debit total clearly displayed  
* Cash out amount clearly displayed  
* Liability creation (draft) visible in summary

---

## 6.3 Transfer

Must include:

* Dual reference panels (From/To)  
* Real-time projected balances on both accounts  
* Explicit “No cash movement” indication  
* Balanced debit/credit preview

---

## 6.4 Non-Customer Check Cashing

Must include:

* Check details  
* Required identification fields  
* Risk/aggregate monitoring display  
* Fee breakdown  
* Net cash payout  
* CTR/threshold indicator  
* Clearing exposure indicator

---

# 7\. Prohibited Behaviors

The system must not:

* Clear form due to validation  
* Modify posted transactions  
* Allow posting while out of balance  
* Hide projected balance impact  
* Hide cash movement impact  
* Allow silent supervisor overrides  
* Require fixed row counts for dynamic inputs

---

# 8\. Accessibility & Operational Efficiency

Minimum requirements:

* Full keyboard navigation  
* Logical tab order  
* Auto-focus on first required field  
* Numeric keypad friendly  
* Fast entry optimized for high-volume use

---

# 9\. Control Objectives Supported

These UI standards support:

* Cash accountability  
* Double-entry enforcement  
* Reduced over/short conditions  
* Segregation of duties  
* Threshold enforcement  
* Audit traceability  
* Risk visibility

The teller UI is considered a first-line control layer.

---

# 10\. Future Extensibility

This structure must remain compatible with:

* Full CIF expansion  
* Full GL engine integration  
* Fee engine  
* CTR/SAR reporting automation  
* Multi-channel transaction origination

No UI standard adopted in Iteration 1 may preclude future domain expansion.

---

# Appendix A — Page Acceptance Checklist

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
