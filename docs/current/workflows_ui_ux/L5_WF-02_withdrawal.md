## L5-WF-02 — Withdrawal (WS-210)

**Status:** **Fits but needs working changes** — cash withdrawal is implemented, but draft/mixed and approval-window details in this doc are not currently implemented.
**Current Implementation Mapping:** UI flow is `GET /teller/transactions/withdrawal`; validation/posting are `POST /teller/transactions/validate` and `POST /teller/posting`; receipt is `GET /teller/receipts/:request_id`.
**Implementation:** Implemented. See [00_page_endpoint_list.md](00_page_endpoint_list.md) for route mapping.

---

# 1) Purpose

Disburse funds from a customer account via:

* **Cash** (default)
* **Bank Draft** (optional within withdrawal if you allow “mixed”)
* **Mixed** (cash + draft)

Produces:

* Posted teller transaction
* Balanced double-entry posting batch
* Receipt block

---

# 2) Routes

* `GET  /teller/transactions/withdrawal`
* `POST /teller/transactions/withdrawal`
* `GET  /teller/transactions/:id/receipt` (optional but recommended)

---

# 3) Preconditions (blocking)

* Workstation context present
* Workstation not locked
* **Open teller session** exists for `Current.user + Current.workstation`
* Funding account exists and is eligible
* Customer account status allows withdrawal (e.g., not frozen/closed)

If not:

* 422 blocking banner + inline errors (or redirect to WS-100 if “no session” per your global rule)

---

# 4) Screen structure (Traditional / Workstation shell)

Zones (same as Deposit):

1. Context bar (display-only)
2. Command bar (not tabbable)
3. Header: `WITHDRAWAL`
4. Banner region
5. Main:

   * Entry form (tabbable)
   * Account reference panel (read-only)
6. Totals panel (read-only)
7. Drawer footer (read-only)
8. Approval modal
9. Receipt block

---

# 5) Entry form fields (tab order)

1. Account search/select *(required)*
2. Withdrawal amount *(required)*
3. Disbursement method *(required)*

   * Cash
   * Draft
   * Mixed
4. Cash amount *(required if Cash or Mixed)*
5. Draft amount *(required if Draft or Mixed)*
6. Draft details *(required if Draft or Mixed)*

   * Payee (recommended required)
   * Draft memo (optional)
   * Draft serial (if system assigns; if manual, required)
7. Fee (optional; auto-calculated default)
8. Fee override toggle / amount *(only if allowed; triggers approval)*
9. ID verification section *(conditional, if policy requires)*
10. Memo (optional)
11. Cancel
12. Post (Ctrl+Enter)

**Derived rule (blocking):**

* `cash_amount + draft_amount == withdrawal_amount`

### 5.1 Required and optional fields (authoritative)

See [02_teller_transaction_requirements.md](02_teller_transaction_requirements.md) for the authoritative required/optional field list and server validation behavior for Withdrawal.

---

# 6) Totals model

## 6.1 Totals panel must show

* Withdrawal amount
* Fee (if any)
* Total debit to customer (amount + fee, depending on your fee model)
* Disbursement breakdown:

  * Cash Out
  * Draft Issued

## 6.2 Drawer footer impact

* Cash Out reduces drawer
* Draft issuance does **not** affect drawer cash (it affects a “drafts issued” instrument bucket / liability)

Drawer impact display:

* `Drawer Before`
* `- Cash Out`
* `Drawer After`

If cash out is 0 (draft-only):

* `NO CASH MOVEMENT`

---

# 7) Approval triggers (withdrawal-specific)

Withdrawal is the highest-risk flow. Approval triggers are typically more aggressive.

## 7.1 Mandatory approval triggers (recommended)

| Trigger                                              | Approval type                |
| ---------------------------------------------------- | ---------------------------- |
| Withdrawal amount ≥ threshold                        | `withdrawal_over_limit`      |
| Cash out ≥ cash threshold                            | `withdrawal_cash_over_limit` |
| After-hours withdrawal                               | `withdrawal_after_hours`     |
| Fee override                                         | `fee_override`               |
| Overdraft / insufficient funds override (if allowed) | `overdraft_override`         |

## 7.2 Conditional triggers

| Trigger                    | Approval type                                             |
| -------------------------- | --------------------------------------------------------- |
| Draft issuance ≥ threshold | `draft_over_limit`                                        |
| Customer/account flagged   | `account_restriction_override` *(if you implement flags)* |

## 7.3 Blocking vs override policy (must be explicit)

Two acceptable Phase 1 patterns:

* **Pattern A (safer):** insufficient funds is **blocking** (no override)
* **Pattern B (supported):** insufficient funds can be overridden **with approval** (`overdraft_override`)

Your earlier direction implies you want approval-based overrides available. If so:

* show neutral `[APPROVAL REQUIRED]` when insufficient funds and override is permitted by policy.

---

# 8) Posting legs (double-entry)

This is the canonical accounting map.

### 8.1 Customer side (always)

* **Debit**: Customer Account — `withdrawal_amount`
* **Debit**: Customer Account — `fee_amount` *(if fee charged to customer)*
* **Credit**: Fee Income — `fee_amount` *(if fee exists)*

### 8.2 Disbursement side

**Cash portion**

* **Credit**: Cashbox (Drawer Cash Out) — `cash_amount`

**Draft portion**

* **Credit**: Bank Drafts Outstanding (liability) *or* Draft Clearing account — `draft_amount`
* Draft serial/payee metadata stored on teller transaction / context JSON for audit & receipt

**Balance check**

* Total credits (cash_out + draft_out + fee_income?) must equal total debits (customer amount + fee as applicable)

> If you model fees as “withheld from proceeds” instead of “added”, adjust the UI totals and legs accordingly. Phase 1 contract assumes fee is charged in addition to the withdrawal amount (common for teller fees). If you want “fee included in amount”, say so and I’ll lock an alternate.

---

# 9) Validation rules (blocking)

* Account required
* Withdrawal amount > 0
* Disbursement method required
* If cash/draft amounts required: each >= 0 and:

  * cash + draft == withdrawal amount
* Fee >= 0 (if provided)
* If draft used:

  * payee required
  * serial required if not system-assigned
* If ID required by policy: required fields must be present

Server authoritative validations:

* account status
* available balance
* holds/restrictions
* policy thresholds

---

# 10) Approval behavior (must match global contract)

* Approval-required state is neutral
* Post triggers approval modal
* Supervisor window reuse applies
* Approval binds to **idempotency_key** for the pending attempt
* Denied approval returns to form with no clearing

---

# 11) Idempotency

Withdrawal POST includes `idempotency_key`.

Server behavior:

* duplicate submit returns existing receipt; never double-deduct.

---

# 12) Receipt requirements (Withdrawal)

Receipt must show:

* Ref #
* Timestamp
* Account masked + name
* Withdrawal amount
* Fee (if any)
* Total debit
* Disbursement breakdown:

  * Cash paid out
  * Draft amount + payee + serial (if draft used)
* Drawer before/after if cash involved
* Approval stamp if approval used

Actions:

* Print Receipt
* New Withdrawal

Focus:

* New Withdrawal

---

# 13) Ops visibility requirements

Withdrawal appears in:

* OPS teller activity totals (cash out, drafts issued, fees)
* OPS session detail list
* Approval linkage visible (who approved, when)

---

# 14) Acceptance checklist (WS-210)

* [ ] Requires open teller session
* [ ] Supports Cash / Draft / Mixed
* [ ] Enforces cash+draft == withdrawal amount
* [ ] Drawer impact reflects cash only
* [ ] Handles insufficient funds as either blocking or approval override (policy-locked)
* [ ] All approvals use standard modal + window reuse + binding to idempotency_key
* [ ] Balanced posting legs for cash and draft components
* [ ] Receipt shows full breakdown + approval stamp
* [ ] Idempotency prevents duplicates
