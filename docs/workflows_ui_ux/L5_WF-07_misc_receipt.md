## L5-WF-07 — Misc. Receipt (WS-260)

**Status:** **Not aligned with current codebase**
**Current Implementation Mapping:** Misc Receipt workflow/routes/controllers are not implemented in teller routes today.

---

# 1) Purpose

Accept incoming funds that do **not** map to standard deposit/bill workflows.

Typical use cases:

* Internal fee collection
* Loan payment (if not yet modeled separately)
* Safe deposit box fee
* Returned item fee
* Miscellaneous GL-coded receipt

Produces:

* Posted teller transaction
* Balanced posting batch
* Receipt block

---

# 2) Routes

* `GET  /teller/transactions/misc_receipt`
* `POST /teller/transactions/misc_receipt`
* `GET  /teller/transactions/:id/receipt` (optional but recommended)

---

# 3) Preconditions (blocking)

* Workstation context present
* Workstation not locked
* **Open teller session** exists
* GL / receipt classification selected and valid

If fail:

* 422 blocking banner + inline errors
  (or redirect to WS-100 if “no session” per global rule)

---

# 4) Screen structure (Traditional / Workstation shell)

Zones:

1. Context bar (display-only)
2. Command bar (not tabbable)
3. Header: `MISC RECEIPT`
4. Banner region
5. Main:

   * Entry form (tabbable)
   * Reference panel (optional: account or customer if used)
6. Totals panel (read-only)
7. Drawer footer (read-only)
8. Approval modal (if required)
9. Receipt block

---

# 5) Entry form fields (tab order)

Minimum Phase 1 set:

1. Receipt category *(required)*

   * Select list mapped to GL destination (e.g., Fee Income, Other Income, Loan Payment Clearing, etc.)
2. Reference account *(optional, policy-driven)*

   * Required if category demands account context
3. Amount *(required, > 0)*
4. Funding method *(required)*

   * Cash
   * Account
   * Mixed (optional)
5. Funding account *(required if Account or Mixed)*
6. Cash received *(required if Cash or Mixed)*
7. Memo / description *(required for audit defensibility; recommended required)*
8. Cancel
9. Post (Ctrl+Enter)

---

# 6) Totals and cash impact

## 6.1 Totals panel must show

* Receipt amount
* Funding breakdown:

  * Account debit (if used)
  * Cash received (if used)

## 6.2 Drawer footer

If cash involved:

* `Drawer Before`
* `+ Cash In`
* `Drawer After`

If no cash:

* `NO CASH MOVEMENT`

**Phase 1 rule:**
If cash is used, require exact amount (no change-due behavior).

---

# 7) Approval triggers (policy-driven)

Misc receipts can be sensitive if they allow arbitrary GL coding.

| Trigger                          | Approval type                  |
| -------------------------------- | ------------------------------ |
| Amount ≥ threshold               | `misc_receipt_over_limit`      |
| Category flagged as sensitive GL | `misc_gl_sensitive`            |
| After-hours                      | `misc_after_hours`             |
| Account override                 | `account_restriction_override` |

Approval behavior:

* Neutral `[APPROVAL REQUIRED]`
* Supervisor window reuse allowed
* Approval binds to idempotency key

---

# 8) Posting legs (double-entry)

Canonical map:

## 8.1 Credit GL category

* **Credit**: Selected GL Income / Clearing account — `amount`

## 8.2 Funding side

If funded by account:

* **Debit**: Customer Account — `account_debit_amount`

If funded by cash:

* **Debit**: Cashbox (Drawer Cash In) — `cash_received_amount`

If mixed:

* debit both appropriately

**Balance invariant**
Total debits (funding) == total credits (GL category).

---

# 9) Validation rules (blocking)

* Category required
* Amount > 0
* Memo required (recommended)
* Funding method required
* If account funding:

  * account required + eligible + sufficient funds (blocking or approval override per policy)
* If cash funding:

  * cash_received == amount

Server authoritative:

* policy threshold checks
* GL category validity
* approval triggers

---

# 10) Idempotency

Misc receipt POST includes `idempotency_key`.

Server must ensure:

* duplicate submit returns same receipt; never double-post.

---

# 11) Receipt requirements (Misc Receipt)

Receipt must include:

* Ref #
* Timestamp
* Category label
* Amount
* Funding breakdown
* Memo/description
* Drawer before/after if cash used
* Approval stamp if used

Actions:

* Print Receipt
* New Misc Receipt

Focus:

* New Misc Receipt

---

# 12) Ops visibility

Misc receipt appears in:

* OPS teller activity totals (cash in + GL totals)
* OPS session detail
* Approval linkage visible if used

---

# 13) Acceptance checklist (WS-260)

* [ ] Requires open teller session
* [ ] Category selection required and maps to GL account
* [ ] Memo required (recommended)
* [ ] Funding method enforced
* [ ] Cash impact only when cash used
* [ ] Approval triggers consistent with policy
* [ ] Balanced posting: GL credit + funding debits
* [ ] Receipt includes category + memo + approval stamp
* [ ] Idempotency prevents duplicate receipts
