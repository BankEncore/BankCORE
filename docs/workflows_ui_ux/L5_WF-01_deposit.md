## L5-WF-01 — Deposit (WS-200)

**Status:** **DROP-IN SAFE (schema-aligned)** — uses your existing teller + posting infrastructure and the global posting/approval/receipt contracts already locked.

---

# 1) Purpose

Accept funds into a customer account using:

* **Cash in**
* **Checks in** (one or more)

Produces:

* A posted teller transaction
* Balanced double-entry posting batch
* Receipt block (print + new deposit)

---

# 2) Routes

* `GET  /teller/transactions/deposit` → WS-200 Editing
* `POST /teller/transactions/deposit` → Validate / Approval / Post / Receipt
* `GET  /teller/transactions/:id/receipt` → WS-031 reuse (optional but recommended for reprint/view)

---

# 3) Preconditions (blocking)

* WS context present (branch + workstation)
* Workstation not locked
* **Open teller session** exists for `Current.user + Current.workstation`
* Target account exists and is eligible to accept deposits (status checks)

If any fail:

* return 422 with blocking banner + stay in Editing state (except missing session may redirect to WS-100 per your global routing rule)

---

# 4) Screen structure (Traditional / Workstation shell)

**Zones:**

1. Context bar (display-only)
2. Command bar (not tabbable)
3. Header: `DEPOSIT`
4. Banner region
5. Main:

   * Left: Entry form (tabbable)
   * Right: Account reference panel (read-only)
6. Totals panel (read-only)
7. Drawer footer (read-only)
8. Approval modal (if needed)
9. Receipt block (after post)

---

# 5) Entry form fields (tab order)

1. Account search/select *(required)*
2. Cash amount *(optional; default 0)*
3. Checks section:

   * Add check row button (not in tab order if you want strict form scope; acceptable either way)
   * For each check row:

     1. Check amount *(required if row exists)*
     2. Check number *(recommended)*
     3. Routing/account (optional Phase 1 unless required)
     4. Hold toggle (optional; if enabled shows hold reason)
4. Memo (optional)
5. Cancel
6. Post (Ctrl+Enter)

**Rules:**

* Deposit must have **cash > 0 or at least one check row** with amount > 0
* Removing all check rows + cash = 0 is blocking

---

# 6) Totals model (server authoritative)

## 6.1 Totals panel must show

* Cash In
* Checks In (sum)
* Total Deposit

## 6.2 Drawer footer impact

Deposit affects drawer:

* Cash increases drawer
* Checks do **not** affect cash (but may affect “items received” tracking if you later add it)

Drawer impact display:

* `Drawer Before`
* `+ Cash In`
* `Drawer After`

If cash is 0:

* Show `NO CASH MOVEMENT` (still allowed because checks deposit is valid)

---

# 7) Approval triggers (policy-driven)

Deposit approvals are **conditional**, not mandatory.

Recommended approval triggers:

| Trigger                                      | Approval type              |
| -------------------------------------------- | -------------------------- |
| Total deposit ≥ threshold                    | `deposit_over_limit`       |
| Any single check ≥ threshold                 | `deposit_check_over_limit` |
| Hold override / force immediate availability | `deposit_hold_override`    |

**Non-blocking warnings** (do not require approval unless policy escalates):

* unusually large deposit advisory
* suspicious pattern advisory (future)

Approval behavior:

* Neutral `[APPROVAL REQUIRED]`
* Post triggers approval modal
* 5-minute window reuse applies

---

# 8) Posting legs (double-entry model)

This is the canonical accounting map for Phase 1 deposit.

### 8.1 Cash component

* **Debit**: Cashbox (Drawer Cash) — `cash_amount`
* **Credit**: Customer Deposit Liability / Account — `cash_amount`

### 8.2 Check component

* **Debit**: Cashbox (Checks Received) or “Checks In Transit” — `check_total`
* **Credit**: Customer Deposit Liability / Account — `check_total`

**Important:** cash and checks are separate “cashbox buckets” (even if they roll to a single drawer balance display later).

### 8.3 Net result

* Customer Account credited with (cash + checks)
* Assets increased in correct internal buckets

Server must enforce:

* Sum debits == sum credits

---

# 9) Validation rules (blocking)

* Account required
* Amounts numeric, ≥ 0
* At least one funding source present (cash > 0 OR checks_total > 0)
* Check rows must have amount > 0
* Optional: check number required if check row exists (recommended)
* Teller session must be open

If validation fails:

* 422 + inline errors, focus first invalid field

---

# 10) Idempotency

Deposit posts must include `idempotency_key`.

Server must ensure:

* same idempotency key returns same posted receipt (no duplicates)

---

# 11) Receipt requirements (Deposit)

Receipt must show:

* Ref #
* Posted timestamp
* Account masked + name
* Cash received amount
* Checks received list (amounts; check # if captured)
* Total deposit
* Drawer before/after if cash involved
* Approval stamp if approval used

Actions:

* Print Receipt
* New Deposit

Focus:

* New Deposit

---

# 12) Ops visibility requirements

Deposit must appear in:

* OPS teller activity totals
* OPS session detail transaction list

If deposit had approval:

* approval record must be joinable from ops detail

---

# 13) Acceptance checklist (WS-200)

* [ ] Requires open teller session
* [ ] Allows cash-only, checks-only, or mixed deposits
* [ ] Totals panel always shows cash/check/total
* [ ] Drawer impact only reflects cash portion
* [ ] Approval required triggers consistent modal + window reuse
* [ ] Posts balanced entries with separate cash/check buckets
* [ ] Receipt includes breakdown + masked account + approval stamp
* [ ] Idempotency prevents duplicate posting
