## L5-WF-05 — Bank Draft (WS-240)

**Status:** **Partially aligned with current codebase**
**Current Implementation Mapping:** Bank Draft is implemented under the `draft` workflow surfaces: `GET /teller/transactions/draft`, `GET /teller/drafts/new`, `POST /teller/drafts`.

---

# 1) Purpose

Issue an official bank draft (teller check / cashier’s check style instrument) funded by:

* **Customer account debit** *(typical)*
  and/or
* **Cash** *(optional; policy-driven)*

Produces:

* Posted teller transaction
* Balanced posting batch
* Receipt block
* Draft instrument metadata (serial/payee) recorded for audit

---

# 2) Routes

* `GET  /teller/transactions/bank_draft`
* `POST /teller/transactions/bank_draft`
* `GET  /teller/transactions/:id/receipt` (optional but recommended)

---

# 3) Preconditions (blocking)

* Workstation context present
* Workstation not locked
* **Open teller session** exists
* Draft issuance permitted for teller role/branch
* Draft stock/serial source available *(policy/implementation)*

If fail:

* 422 blocking banner + inline errors (or redirect to WS-100 if “no session” per your global rule)

---

# 4) Screen structure (Traditional / Workstation shell)

Zones:

1. Context bar (display-only)
2. Command bar (not tabbable)
3. Header: `BANK DRAFT`
4. Banner region
5. Main:

   * Entry form (tabbable)
   * Funding account reference (read-only) *(if selected)*
6. Totals panel (read-only)
7. Drawer footer (read-only)
8. Approval modal (if required)
9. Receipt block

---

# 5) Entry form fields (tab order)

Minimum Phase 1 set:

1. Funding method *(required)*

   * Customer account
   * Cash
   * Mixed *(optional; allow if you want parity with withdrawal)*
2. Funding account search/select *(required if customer account or mixed)*
3. Draft amount *(required, > 0)*
4. Fee *(optional; auto-calculated default)*
5. Fee override *(if allowed; triggers approval)*
6. Payee name *(required)*
7. Remitter name *(optional; recommended)*
8. Draft memo / reference *(optional; recommended)*
9. Draft serial *(required unless system assigns at post time)*
10. Cash received *(required if cash or mixed)*
11. Memo (internal) *(optional)*
12. Cancel
13. Post (Ctrl+Enter)

**Derived rule (blocking if mixed):**

* `cash_received + account_debit == draft_amount + fee_amount` *(if fee charged in addition)*

> If you want “fee included” instead, we can lock that, but current contract assumes fee is charged on top.

---

# 6) Totals and cash impact

## 6.1 Totals panel must show

* Draft amount
* Fee (if any)
* Total funds required
* Funding breakdown:

  * Account debit
  * Cash received

## 6.2 Drawer footer impact

* Cash received increases drawer
* If cash is 0 → `NO CASH MOVEMENT`

---

# 7) Approval triggers (high control)

Draft issuance is an instrument/liability event.

| Trigger                                | Approval type                                                       |
| -------------------------------------- | ------------------------------------------------------------------- |
| Draft amount ≥ threshold               | `draft_over_limit`                                                  |
| After-hours issuance                   | `draft_after_hours`                                                 |
| Fee override                           | `fee_override`                                                      |
| Cash-funded draft ≥ cash threshold     | `draft_cash_over_limit`                                             |
| Manual serial entry / serial exception | `draft_serial_override` *(optional; only if you support overrides)* |

Approval behavior:

* Neutral `[APPROVAL REQUIRED]`
* Supervisor window reuse allowed
* Approval binds to idempotency key

---

# 8) Posting legs (double-entry)

Canonical accounting map (Phase 1):

## 8.1 Issue draft (liability created)

* **Credit**: Bank Drafts Outstanding (liability) — `draft_amount`

## 8.2 Funding side

If funded by account:

* **Debit**: Customer Account — `account_debit_amount`

If funded by cash:

* **Debit**: Cashbox (Drawer Cash In) — `cash_received_amount`

If funded by mixed:

* debit both as above.

## 8.3 Fee (income) (if applicable)

If fee charged:

* **Debit**: Customer Account **or** Cashbox (depending on funding method) — `fee_amount`
* **Credit**: Fee Income — `fee_amount`

**Balance check**
Total debits (funding + fee source) must equal total credits (draft liability + fee income if separate posting).

---

# 9) Validation rules (blocking)

* Funding method required
* Draft amount > 0
* Payee required
* Serial required unless system-assigned
* If account funding: account required + eligible + sufficient funds (blocking or approval override per policy)
* Fee >= 0
* If cash funding: cash_received >= total required

  * If you allow change due for drafts (not recommended), define it explicitly; default is **exact funds required**.

Phase 1 recommendation:

* For cash funding: require cash_received == total required (no “change due” in draft workflow)

---

# 10) Idempotency

Bank Draft POST includes `idempotency_key`.

Server ensures:

* duplicate submit returns same receipt; never creates two drafts.

---

# 11) Receipt requirements (Bank Draft)

Receipt must include:

* Ref #
* Timestamp
* Payee
* Draft amount
* Draft serial/reference
* Funding breakdown (account and/or cash)
* Fee (if any)
* Drawer before/after if cash received
* Approval stamp if used

Actions:

* Print Receipt
* New Bank Draft

Focus:

* New Bank Draft

---

# 12) Ops visibility

Draft issuance must appear in:

* OPS teller activity totals (drafts issued, fees, cash in if any)
* OPS session detail
* Approval linkage visible if used
* Draft serial searchable later (Ops enhancement; note for Phase 1.1)

---

# 13) Acceptance checklist (WS-240)

* [ ] Requires open teller session
* [ ] Payee + amount + serial captured
* [ ] Funding method enforced (account/cash/mixed)
* [ ] Cash impact only when cash received
* [ ] Approval triggers consistent (threshold/after-hours/fee override)
* [ ] Balanced posting: draft liability credit + funding debits + fee income
* [ ] Receipt includes serial + payee + approval stamp
* [ ] Idempotency prevents duplicate drafts