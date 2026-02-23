## L5-WF-04 — Check Cashing (WS-230)

**Status:** **Fits but needs working changes** — check cashing workflow is implemented, but policy and contract sections should align to current approval-token model.
**Current Implementation Mapping:** UI flow is `GET /teller/transactions/check_cashing`; validation/posting are `POST /teller/transactions/validate` and `POST /teller/posting`; receipt is `GET /teller/receipts/:request_id`.
**Implementation:** Implemented. See [00_page_endpoint_list.md](00_page_endpoint_list.md) for route mapping.

---

# 1) Purpose

Cash a check presented by a customer (or non-customer, if allowed) by:

* Receiving the check (non-cash instrument in)
* Paying out cash (cash out)
* Charging an optional fee

Produces:

* Posted teller transaction
* Balanced double-entry posting batch
* Receipt block

---

# 2) Routes

* `GET  /teller/transactions/check_cashing`
* `POST /teller/transactions/check_cashing`
* `GET  /teller/transactions/:id/receipt` (optional but recommended)

---

# 3) Preconditions (blocking)

* Workstation context present
* Workstation not locked
* **Open teller session** exists
* Check cashing allowed by policy for teller/branch
* If customer account is required (policy): account must exist and be eligible

If fail:

* 422 blocking banner + inline errors (or redirect to WS-100 per your global “no session” rule)

---

# 4) Screen structure (Traditional / Workstation shell)

Zones:

1. Context bar (display-only)
2. Command bar (not tabbable)
3. Header: `CHECK CASHING`
4. Banner region
5. Main:

   * Entry form (tabbable)
   * Reference panel:

     * Optional customer/account reference (read-only if selected)
     * Policy/verification status lines (read-only)
6. Totals panel (read-only)
7. Drawer footer (read-only)
8. Approval modal (if required)
9. Receipt block

---

# 5) Entry form fields (tab order)

Minimum Phase 1 set:

1. Customer type *(required)*

   * Customer (requires account lookup)
   * Non-customer (requires ID capture fields)
2. Account search/select *(required if Customer)*
3. Check amount *(required, > 0)*
4. Check identifier fields *(recommended required)*

   * Check number
   * Routing/account (optional unless policy requires)
5. Fee *(optional; auto-calculated default)*
6. Fee override (if allowed) *(triggers approval)*
7. Cash payout amount *(computed)* (read-only)

   * `cash_payout = check_amount - fee` *(see §6.1)*
8. ID verification *(required if Non-customer; optional if customer by policy)*

   * ID type
   * ID last4 or number (masked)
   * Expiration (optional)
9. Memo (optional)
10. Cancel
11. Post (Ctrl+Enter)

**Rule:** You do not allow “draft payout” for check cashing in Phase 1 unless you explicitly add it. Default is cash only.

### 5.1 Required and optional fields (authoritative)

See [02_teller_transaction_requirements.md](02_teller_transaction_requirements.md) for the authoritative required/optional field list and server validation behavior for Check Cashing.

---

# 6) Totals and cash impact

## 6.1 Totals panel must show

* Check amount (instrument in)
* Fee (if any)
* Cash paid out (net)
* Status: BALANCED

Net math:

* `cash_out = check_amount - fee_amount`
* Require: `fee_amount <= check_amount` (blocking)

## 6.2 Drawer footer impact

* Drawer decreases by cash_out

Display:

* `Drawer Before`
* `- Cash Out`
* `Drawer After`

---

# 7) Approval triggers (high-risk)

Check cashing has elevated risk; approvals are common.

| Trigger                                                       | Approval type                                          |
| ------------------------------------------------------------- | ------------------------------------------------------ |
| Amount ≥ threshold                                            | `check_cashing_over_limit`                             |
| Non-customer                                                  | `check_cashing_non_customer` *(recommended mandatory)* |
| Fee override                                                  | `fee_override`                                         |
| Manual verification override (if you have verification flags) | `check_cashing_verification_override`                  |

**Policy note (Phase 1 recommendation):**

* Treat **non-customer check cashing** as *approval required by default*.

Approval behavior:

* Neutral `[APPROVAL REQUIRED]`
* Post triggers modal
* Supervisor window reuse allowed
* Approval binds to idempotency key

---

# 8) Posting legs (double-entry)

Canonical accounting map:

### 8.1 Receive check (asset in)

* **Debit**: Checks Received / Cash Items (asset) — `check_amount`

### 8.2 Pay cash out (asset out)

* **Credit**: Cashbox (Drawer Cash Out) — `cash_out`

### 8.3 Fee (income)

If fee charged:

* **Credit**: Fee Income — `fee_amount`

### 8.4 Balance

Debits: `check_amount`
Credits: `cash_out + fee_amount`
Since `cash_out = check_amount - fee_amount`, totals balance.

---

# 9) Validation rules (blocking)

* Customer type required
* If customer:

  * account required and eligible
* Check amount > 0
* Fee >= 0 and fee <= check amount
* If non-customer:

  * ID fields required (minimum set)
* Open teller session required

Server authoritative validations:

* branch/teller authorization
* thresholds / approval requirements
* any “verification” requirements you later implement

---

# 10) Idempotency

Check cashing POST includes `idempotency_key`.

Server ensures:

* double-submit returns same receipt; never double-pay cash.

---

# 11) Receipt requirements (Check Cashing)

Receipt must include:

* Ref #
* Timestamp
* Customer vs non-customer indicator
* (If customer) account masked + name
* Check amount
* Fee (if any)
* Cash paid out
* Check number (and routing/account if captured)
* Drawer before/after
* Approval stamp if used (very likely)

Actions:

* Print Receipt
* New Check Cashing

Focus:

* New Check Cashing

---

# 12) Ops visibility

Check cashing appears in:

* OPS teller activity totals (cash out + fees)
* OPS session detail list
* Approval linkage visible if used

---

# 13) Acceptance checklist (WS-230)

* [ ] Requires open teller session
* [ ] Supports customer and non-customer paths
* [ ] Enforces cash_out = check_amount - fee
* [ ] Fee override requires approval
* [ ] Non-customer requires approval (default)
* [ ] Posts balanced legs (checks received asset, cash out, fee income)
* [ ] Receipt includes check identifiers + cash out + approval stamp
* [ ] Idempotency prevents duplicate payouts
