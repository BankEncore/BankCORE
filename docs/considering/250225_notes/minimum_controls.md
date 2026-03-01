Below is a **Minimum Controls for Phase 1 BankCORE** specification.

This defines the smallest control set required for a teller-posting engine to be regulator-defensible for a community bank / credit union environment.

---

# BankCORE

## Minimum Controls Specification — Phase 1 (Teller Posting Engine)

**Scope:** TellerTransaction, PostingBatch, PostingLeg, AccountTransaction, CashMovement
**Objective:** Ensure accounting integrity, audit defensibility, and operational control.

---

# 1️⃣ Financial Integrity Controls (Non-Negotiable)

## 1.1 Double-Entry Enforcement

**Control Objective:** No unbalanced financial commit may persist.

### Required Controls

* Balance validation executed inside the same DB transaction as commit.
* Commit must fail if:

  * Sum(debits) ≠ Sum(credits)
  * Any amount_cents ≤ 0
  * Currency mismatch

### Hard Requirement

Balance check must occur:

* After legs are finalized
* Immediately before persistence
* Inside database transaction block

---

## 1.2 Immutability Enforcement

**Control Objective:** Financial records cannot be altered after commit.

### Required Controls

At database level:

* `posting_legs`:

  * No UPDATE
  * No DELETE

* `posting_batches`:

  * No UPDATE except status transitions explicitly allowed
  * No DELETE

* `account_transactions`:

  * No UPDATE except running_balance recalculation (if used)
  * No DELETE

### Implementation Options

* DB trigger rejecting UPDATE/DELETE
* Database role separation (application user lacks UPDATE/DELETE privilege)
* Append-only ledger model

---

## 1.3 Idempotency & Concurrency

**Control Objective:** Prevent duplicate posting under concurrent requests.

### Required Controls

* Unique DB index on `request_id`
* Entire commit wrapped in DB transaction
* On unique constraint violation:

  * Return existing posting batch
  * Do NOT partially fail

### Required Behavior

Posting must be atomic and deterministic under retry conditions.

---

# 2️⃣ Reversal Governance (Mandatory)

## 2.1 Explicit Reversal Model

Silent correction is prohibited.

### Required Schema Addition

Add one of:

```
reversal_of_posting_batch_id
```

OR

```
reversal_of_teller_transaction_id
```

### Required Behavior

* Reversal creates a new PostingBatch
* Legs are exact opposite of original
* Link stored bidirectionally
* Original batch remains immutable

---

## 2.2 Reversal Authorization

**Control Objective:** Segregation of duties.

### Required Controls

* Reversal requires elevated role

* Record:

  * approving_user_id
  * approval_timestamp
  * reason_code
  * free-text memo

* Reversal must not occur automatically without explicit approval

---

# 3️⃣ Segregation of Duties (Operational Controls)

## 3.1 Role-Based Transaction Authorization

Each transaction type must require explicit permission:

| Transaction    | Permission Required |
| -------------- | ------------------- |
| Deposit        | post_deposit        |
| Withdrawal     | post_withdrawal     |
| Vault Transfer | post_vault_transfer |
| Draft          | post_draft          |
| Check Cashing  | post_check_cashing  |
| Reversal       | post_reversal       |

Permissions must be:

* Role-based
* Enforced at controller/service layer
* Logged on violation attempts

---

## 3.2 Supervisor Overrides

For:

* Large transactions
* Check cashing above threshold
* Manual fee overrides
* Reversals

System must log:

* initiating_user_id
* approving_user_id
* approval_timestamp
* approval_window_duration

---

# 4️⃣ Audit & Traceability Controls

## 4.1 Financial Audit Log

Add append-only `financial_audit_events` table.

Minimum fields:

* event_type
* actor_user_id
* target_model
* target_id
* request_id
* ip_address
* created_at
* metadata (JSON)

Log events:

* Posting committed
* Reversal initiated
* Reversal approved
* Reversal committed
* Failed posting attempt
* Unauthorized attempt

---

## 4.2 Metadata Validation

PostingBatch.metadata must:

* Be validated by transaction_type
* Reject missing required keys
* Reject unexpected schema versions

Optional but recommended:

* Add metadata_schema_version

---

# 5️⃣ Cash Control Safeguards

## 5.1 Drawer Integrity

* Enforce only one drawer per session
* Enforce that vault transfers include one leg matching session drawer
* Fail if ambiguous cash legs detected

## 5.2 Session Close Integrity

On session close:

* Compare declared cash vs expected
* Require supervisor override for variance beyond tolerance
* Log override event

---

# 6️⃣ Referential Integrity Controls

## 6.1 Foreign Key Constraints

All FKs must:

* Be NOT NULL (except optional account_id)
* Use ON DELETE RESTRICT
* Prevent cascade deletion

## 6.2 Account Number Stability

If using account_reference strings:

* Account numbers must be immutable after creation
* Format must be canonical and validated

---

# 7️⃣ Running Balance Policy

Choose one:

### Option A (Safer Phase 1)

Do not store running_balance_cents.
Compute balance as SUM(account_transactions).

### Option B (If storing)

* Enforce single-writer per account
* Disallow historical inserts
* Recalculate on any reversal
* Lock account row during posting

---

# 8️⃣ Data Retention & Preservation

Financial tables must:

* Never be hard-deleted
* Be included in nightly backups
* Be included in retention policy
* Be exportable for audit

---

# 9️⃣ Operational Monitoring

System must monitor and alert on:

* Duplicate request_id attempts
* Failed balance validation
* Failed metadata validation
* Reversal frequency above threshold
* Cash variance beyond threshold

---

# 10️⃣ Examination Readiness Checklist

Before production use in regulated environment:

* [ ] DB-level immutability enforced
* [ ] Reversal model implemented
* [ ] Supervisor approval logging implemented
* [ ] Financial audit log table implemented
* [ ] Idempotency concurrency tested under load
* [ ] Cash drawer reconciliation workflow documented
* [ ] Role-based authorization fully enforced
* [ ] Backups tested and documented

---

# Phase 1 Control Maturity Rating

If all above are implemented:

* Safety & Soundness: Strong
* Audit Defensibility: Strong
* Teller Control Compliance: Strong
* Operational Risk Exposure: Moderate-to-Low
* Examination Risk: Low

---

# Final Assessment

Your architecture is already structurally sound.

To become regulator-defensible:

You do not need architectural redesign.

You need:

* Enforcement hardening
* Governance formalization
* Reversal discipline
* Audit logging

That is a control layer, not a rewrite.

---

If you’d like next, I can produce:

* A DB hardening implementation blueprint (Rails + MySQL)
* A reversal model technical specification
* Or a regulator-style internal control narrative suitable for policy documentation
