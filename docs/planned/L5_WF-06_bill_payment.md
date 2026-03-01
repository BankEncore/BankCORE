---
status: planned
category: planned
updated: 2026-03-01
---

## L5-WF-06 — Bill Payment (WS-250)

**Status:** **Planned.** Bill Payment workflow/routes/controllers are not implemented.
**Implementation:** See [00_page_endpoint_list.md](../current/workflows_ui_ux/00_page_endpoint_list.md) for route mapping.

---

# 1) Purpose

Accept payment from a customer to remit to a biller/payee.

Funding methods (Phase 1):

* **Customer account debit**
* **Cash**
* **Mixed** (optional but supported)

Produces:

* Posted teller transaction
* Balanced posting batch
* Receipt block
* Payee/reference metadata recorded for audit

---

# 2) Routes

* `GET  /teller/transactions/bill_payment`
* `POST /teller/transactions/bill_payment`
* `GET  /teller/transactions/:id/receipt` (optional but recommended)

---

# 3) Preconditions (blocking)

* Workstation context present
* Workstation not locked
* **Open teller session** exists
* Funding account (if used) exists and eligible
* Payment amount > 0

If fail:

* 422 blocking banner + inline errors
  (or redirect to WS-100 if “no session” per your global rule)

---

# 4) Screen structure (Traditional / Workstation shell)

Zones:

1. Context bar (display-only)
2. Command bar (not tabbable)
3. Header: `BILL PAYMENT`
4. Banner region
5. Main:

   * Entry form (tabbable)
   * Funding account reference (read-only, if selected)
6. Totals panel (read-only)
7. Drawer footer (read-only)
8. Approval modal (if required)
9. Receipt block

---

# 5) Entry form fields (tab order)

1. Payee name *(required)*
2. Account/reference number with payee *(required)*
3. Payment amount *(required, > 0)*
4. Funding method *(required)*

   * Account
   * Cash
   * Mixed
5. Funding account *(required if Account or Mixed)*
6. Cash received *(required if Cash or Mixed)*
7. Fee *(optional; auto-calculated default)*
8. Fee override *(if allowed; triggers approval)*
9. Memo (optional)
10. Cancel
11. Post (Ctrl+Enter)

---

# 6) Totals and cash impact

## 6.1 Totals panel must show

* Payment amount
* Fee (if any)
* Total funds required
* Funding breakdown:

  * Account debit
  * Cash received

## 6.2 Drawer footer

If cash funding present:

* `Drawer Before`
* `+ Cash In`
* `Drawer After`

If no cash:

* `NO CASH MOVEMENT`

**Phase 1 recommendation:**
Require exact cash when cash is used (no “change due” behavior inside bill payment flow).

---

# 7) Approval triggers (policy-driven)

Bill payments are generally lower risk than withdrawals, but still controlled.

| Trigger                                  | Approval type              |
| ---------------------------------------- | -------------------------- |
| Payment amount ≥ threshold               | `bill_payment_over_limit`  |
| Fee override                             | `fee_override`             |
| After-hours payment                      | `bill_payment_after_hours` |
| Insufficient funds override (if allowed) | `overdraft_override`       |

Approval behavior:

* Neutral `[APPROVAL REQUIRED]`
* Supervisor window reuse allowed
* Approval binds to idempotency key

---

# 8) Posting legs (double-entry)

Phase 1 canonical map:

## 8.1 Create payable/remittance liability

* **Credit**: Bill Payments Clearing / Payable Liability — `payment_amount`

## 8.2 Funding side

If funded by account:

* **Debit**: Customer Account — `account_debit_amount`

If funded by cash:

* **Debit**: Cashbox (Drawer Cash In) — `cash_received_amount`

If mixed:

* debit both appropriately

## 8.3 Fee (income)

If fee charged:

* **Debit**: Customer Account or Cashbox (depending on funding method) — `fee_amount`
* **Credit**: Fee Income — `fee_amount`

**Balance invariant**
Total debits (funding + fee source) must equal total credits (payable liability + fee income if separate).

---

# 9) Validation rules (blocking)

* Payee required
* Reference number required
* Payment amount > 0
* Funding method required
* If account funding:

  * account required + eligible + sufficient funds (blocking or approval override per policy)
* If cash funding:

  * cash_received == total required (Phase 1 rule)
* Fee >= 0

Server authoritative:

* branch/teller authorization
* policy threshold checks
* approval triggers

---

# 10) Idempotency

Bill payment POST includes `idempotency_key`.

Server must ensure:

* duplicate submit returns same receipt; never double-post payable.

---

# 11) Receipt requirements (Bill Payment)

Receipt must include:

* Ref #
* Timestamp
* Payee
* Payee reference/account number
* Payment amount
* Fee (if any)
* Funding breakdown (account and/or cash)
* Drawer before/after if cash used
* Approval stamp if used

Actions:

* Print Receipt
* New Bill Payment

Focus:

* New Bill Payment

---

# 12) Ops visibility

Bill payment must appear in:

* OPS teller activity totals (cash in, fees, payable totals)
* OPS session detail
* Approval linkage visible if used
* Future: clearing/reconciliation reports (Phase 2)

---

# 13) Acceptance checklist (WS-250)

* [ ] Requires open teller session
* [ ] Payee + reference captured
* [ ] Funding method enforced (account/cash/mixed)
* [ ] Cash impact only when cash received
* [ ] Approval triggers consistent with policy
* [ ] Balanced posting: payable liability + funding debits + fee income
* [ ] Receipt includes payee + reference + approval stamp
* [ ] Idempotency prevents duplicate payments
