---
status: current
category: current
updated: 2026-03-01
---

Locked: **C) Reversal allowed any time (with supervisor approval).**

This is the most flexible operationally — but it requires very tight policy and audit controls. Below is the finalized **Any-Time Reversal Policy Contract (Phase 1)** aligned with your Posting Engine, audit model, and UI contract.

---

# 🔒 Any-Time Reversal Policy — Phase 1

## 1. Core Rule

A posted transaction may be reversed **at any time**, regardless of:

* Session state (open/closed)
* Business day boundary
* Original teller
* Branch (if multi-branch allowed)

But:

* It must always create a new reversing transaction.
* It must always require supervisor approval.
* It must never modify or delete the original transaction.

---

# 2. Immutable Ledger Requirement

Reversal must:

* Create a new transaction with its own:

  * Reference #
  * Timestamp (server-authoritative)
  * Teller ID (who initiated reversal)
  * Supervisor ID (who approved)
* Link bidirectionally:

  * `original_transaction_id`
  * `reversal_transaction_id`

Original transaction:

* Status remains `POSTED`
* New attribute: `reversed = true`
* Store `reversed_at`
* Store `reversed_by_transaction_id`

Never change original amounts.

---

# 3. Reversal Financial Logic

## 3.1 Full Reversal Only (Phase 1)

* Every leg is mirrored.
* If original had fee → fee is reversed.
* If original affected drawer → drawer impact reversed.
* If original was transfer → both sides reversed.

Example: Withdrawal reversal

Original:

* Debit Account 500
* Credit Cashbox 500

Reversal:

* Credit Account 500
* Debit Cashbox 500

All GL legs must be symmetrical.

---

# 4. Session Interaction Rules

## 4.1 If Session Is OPEN

Reversal:

* Affects current drawer totals immediately.
* Shows drawer impact in receipt.
* Must appear in session activity list.

## 4.2 If Session Is CLOSED

Reversal:

* Posts to the **current open session**.
* Affects current drawer.
* Does NOT reopen the old session.
* Does NOT retroactively modify closed session totals.
* Must be clearly timestamped.

This is critical to avoid corrupting session audit trails.

---

# 5. Approval Contract (Mandatory)

Reversal always:

* Requires supervisor ID + password.
* Requires reversal reason code.
* Requires memo.
* Stores supervisor ID and timestamp.

UI behavior:

* Neutral `[APPROVAL REQUIRED]`
* Reverse button triggers modal.
* No red error styling.

---

# 6. Additional Guardrails (Recommended)

## 6.1 Cannot Reverse:

* A reversal transaction
* A session open/close event
* A transaction already reversed
* A transaction tied to external clearing settlement (if you model that later)
* A transaction marked “sealed” (future EOD lock)

## 6.2 Soft Alerts

If reversing:

* Older than X days → show warning (non-blocking)
* Cross-branch original → show warning
* Large amount → show warning

Warnings do not block; approval still required.

---

# 7. WS-040 Screen Adjustments (Any-Time Mode)

Add informational panel:

```text
Original Posted:
03/10/2026 14:22
Teller: T004
Session: S022 (CLOSED)
```

If original session closed:
Add note:

```text
This reversal will post to the current open session.
```

---

# 8. Drawer Impact Rules

If original affected drawer:

* Reversal affects current drawer.
* Drawer footer must show projected impact before posting.
* Receipt must show updated drawer balance.

If original did not affect drawer (e.g., transfer only):

* Drawer footer shows NO CASH MOVEMENT.

---

# 9. Ops Reporting Requirements

Ops must:

* Show original and reversal paired.
* Show delta (net 0).
* Show who initiated reversal.
* Show who approved reversal.
* Show timestamps for both.

Session detail page must list both original and reversal.

---

# 10. Receipt Format (Reversal)

Receipt must show:

```text
REVERSAL POSTED
Ref #: R-00004529
Reverses: W-00004528
Original Date: 03/10/2026 14:22
Original Teller: T004
Supervisor: S001
Reason: ENTRY_ERROR
Memo: Entered wrong account
```

This ensures audit trace is self-contained.

---

# 11. Phase 1 Constraints (Explicit)

Included:

* Any-time full reversals
* Mandatory supervisor approval
* Cross-session allowed
* Drawer impact reflected immediately

Excluded:

* Partial reversals
* Backdated posting (timestamp must be now)
* Silent auto-reversal
* Batch reversal tools

---

# 12. Policy Risk Note (Why this is Safe)

Because you are:

* Preserving immutable ledger
* Linking original and reversal
* Logging supervisor ID
* Keeping sessions immutable
* Requiring reason + memo
* Displaying reversal explicitly in reports

This is regulator-defensible.

---

# Updated Phase 1 Scope — Finalized

Workstation includes:

* Session lifecycle
* All transaction types
* Vault transfer
* Recent activity
* Receipt viewer
* **Any-time reversal with supervisor**

Ops includes:

* Teller activity reports
* Session search
* Session detail (with reversals visible)
