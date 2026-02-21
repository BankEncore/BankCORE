## L5-WF-03 — Transfer (WS-220)

**Status:** **DROP-IN SAFE (schema-aligned)** — uses the same teller transaction + posting batch infrastructure, with the global posting/approval/receipt contracts.

---

# 1) Purpose

Move funds between two customer accounts (or two deposit accounts) without cash movement.

Produces:

* Posted teller transaction
* Balanced double-entry posting batch
* Receipt block (print + new transfer)

---

# 2) Routes

* `GET  /teller/transactions/transfer`
* `POST /teller/transactions/transfer`
* `GET  /teller/transactions/:id/receipt` (optional but recommended)

---

# 3) Preconditions (blocking)

* Workstation context present
* Workstation not locked
* **Open teller session** exists for `Current.user + Current.workstation`
* From-account exists and is eligible to debit
* To-account exists and is eligible to credit
* Accounts are not the same (unless you explicitly allow intra-account subledger transfers later)

If fail:

* 422 blocking banner + inline errors (or redirect to WS-100 if “no session” per your global rule)

---

# 4) Screen structure (Traditional / Workstation shell)

Zones:

1. Context bar (display-only)
2. Command bar (not tabbable)
3. Header: `TRANSFER`
4. Banner region
5. Main:

   * Entry form (tabbable)
   * Reference panel(s) (read-only): From account + To account
6. Totals panel (read-only)
7. Drawer footer (read-only)
8. Approval modal (if required)
9. Receipt block (after post)

---

# 5) Entry form fields (tab order)

1. From Account search/select *(required)*
2. To Account search/select *(required)*
3. Transfer amount *(required)*
4. Memo (optional)
5. Cancel
6. Post (Ctrl+Enter)

**Rules**

* Amount > 0
* From != To (blocking)

---

# 6) Totals and cash impact

## 6.1 Totals panel must show

* Transfer amount
* Status: BALANCED

## 6.2 Drawer footer

Always show:

* `NO CASH MOVEMENT`

(Transfer does not affect drawer.)

---

# 7) Approval triggers (policy-driven)

Transfer approvals are conditional:

| Trigger                                            | Approval type                  |
| -------------------------------------------------- | ------------------------------ |
| Amount ≥ threshold                                 | `transfer_over_limit`          |
| Overdraft/insufficient funds override (if allowed) | `overdraft_override`           |
| Restricted account override                        | `account_restriction_override` |

**Blocking vs override policy**

* If insufficient funds overrides are allowed, it must require approval (same as Withdrawal).
* Otherwise, insufficient funds is blocking.

---

# 8) Posting legs (double-entry)

Canonical map:

* **Debit**: From Customer Account — `amount`
* **Credit**: To Customer Account — `amount`

Balanced by definition.

No cashbox legs.

---

# 9) Validation rules (blocking)

* From account required
* To account required
* Amount > 0
* From != To
* Account statuses valid (server authoritative)
* Funds availability rules enforced (blocking or approval override)

---

# 10) Approval behavior

If approval required:

* Neutral `[APPROVAL REQUIRED]`
* Post triggers approval modal
* 5-minute window reuse allowed
* Approval binds to idempotency key

---

# 11) Idempotency

Transfer POST includes `idempotency_key`.

Server must ensure:

* repeated submits return same receipt; no double-post.

---

# 12) Receipt requirements (Transfer)

Receipt must show:

* Ref #
* Timestamp
* From account (masked) + name
* To account (masked) + name
* Amount
* Memo (if present)
* `NO CASH MOVEMENT`
* Approval stamp if approval used

Actions:

* Print Receipt
* New Transfer

Focus:

* New Transfer

---

# 13) Ops visibility

Transfer appears in:

* OPS teller activity (count + totals)
* OPS session detail list
* Approval linkage visible if used

---

# 14) Acceptance checklist (WS-220)

* [ ] Requires open teller session
* [ ] From/To accounts validated and cannot match
* [ ] Always shows NO CASH MOVEMENT
* [ ] Posts balanced debit/credit legs only
* [ ] Approval triggers handled consistently (threshold/overdraft/restriction)
* [ ] Receipt shows both accounts + amount + approval stamp if used
* [ ] Idempotency prevents duplicate transfers
