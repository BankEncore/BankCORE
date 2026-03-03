Below is the complete document content for:

`/docs/architecture/STRUCTURAL_AUDIT.md`

You can drop this in as-is.

---

# STRUCTURAL_AUDIT.md

**Project:** BankCORE
**Scope:** Full structural audit of schema, posting engine, teller layer, CIF-lite, and routing
**Date:** 2026-03-02

---

# 1. Executive Summary

BankCORE has successfully moved beyond a prototype teller system and now contains the foundational elements of a core banking substrate:

* Double-entry posting engine
* Idempotent transaction commit workflow
* Stored account balances
* Teller session & drawer control
* Audit event logging
* Role/permission framework
* CIF-lite party structure
* Account ownership modeling

However, the system is currently operating in a transitional state between:

* A string-based reference posting model
  and
* A true typed ledger / subledger architecture

The primary architectural constraint at this stage is:

> Posting references are not first-class entities.

This limits financial reporting, GL integrity, product modeling, and future accrual mechanics.

---

# 2. High-Level Architecture Map

```
Teller UI
   ↓
TellerTransaction
   ↓
Posting::Engine
   ↓
PostingBatch
   ↓
PostingLeg (string account_reference)
   ↓
AccountTransaction (optional account_id)
   ↓
LedgerBalanceUpdater (resolves string → Account)
```

Cash movements are recorded in parallel via:

```
TellerTransaction
   ↓
CashMovement
   ↓
CashLocation
```

Audit logging is handled via:

```
AuditEvent (polymorphic)
```

---

# 3. Domain Inventory

## 3.1 Core Operational Tables

### teller_sessions

* Tracks open/close lifecycle
* Linked to user, branch, workstation
* Stores declared vs calculated totals

### teller_transactions

* Single committed transaction
* Linked to teller_session
* request_id unique (idempotency)
* reversible_reference supported

### cash_locations / cash_location_assignments

* Physical drawer/vault assignment
* Effective lifecycle via assignment records

### cash_movements

* Per-transaction cash tracking
* Linked to teller_transaction

---

## 3.2 Posting Framework

### posting_batches

* request_id unique
* status (committed)
* metadata JSON (validated)

### posting_legs

* debit/credit legs
* account_reference (string)
* no foreign key to account or GL table

### account_transactions

* Linked to posting_batch + teller_transaction
* direction (debit/credit)
* running_balance_cents (currently unused)
* account_id nullable

### accounts

* account_number unique
* account_type (string enum)
* ledger_balance_cents stored
* ledger_balance_updated_at
* status, branch, opened/closed dates

---

## 3.3 CIF-Lite Structure

### parties

* Root entity
* One-to-one extension:

  * party_individuals
  * party_organizations

### account_owners

* account_id
* party_id
* is_primary (not structurally enforced unique)

---

## 3.4 Governance & Controls

### audit_events

* polymorphic
* JSON metadata with DB JSON_VALID constraint

### roles / permissions

* RBAC layer in place

### advisories

* Account/party notes with acknowledgment tracking

---

# 4. Posting & Balance Strategy Analysis

## 4.1 Current Behavior

LedgerBalanceUpdater:

1. Identifies customer account references
2. Resolves reference → account_number
3. Locks Account row
4. increment! ledger_balance_cents

Balances are stored and incrementally maintained.

## 4.2 Observations

* Double-entry integrity is enforced
* Idempotency is enforced
* Account balance is maintained transactionally
* Subledger truth depends on string parsing
* Internal “accounts” (cash:, income:, expense:) are not structured entities

This is stable for teller MVP but limits:

* Trial balance reporting
* Financial statements
* GL control
* Accrual automation
* Product-level accounting rules

---

# 5. Structural Integrity Findings

## 5.1 Strengths

* Atomic posting transactions
* Double-entry enforcement
* Request-level idempotency
* Cash drawer separation
* Audit logging present
* Role-based authorization

## 5.2 Structural Risks

### R1 — Account references are strings

posting_legs.account_reference is not a foreign key.

Impact:

* No referential integrity
* No GL classification
* No financial statement grouping
* Difficult trial balance

---

### R2 — account_transactions.account_id nullable

Customer-facing entries may not be tied to Account.

Impact:

* Reporting inconsistency risk
* Future statement generation complications

---

### R3 — Multiple primary owners possible

account_owners:

* No uniqueness enforcement on (account_id, is_primary)

Impact:

* Ownership ambiguity

---

### R4 — Teller session exclusivity not enforced at DB level

Possible:

* Multiple open sessions per user
* Multiple open sessions per workstation

Impact:

* Operational control weakness

---

### R5 — running_balance_cents not authoritative

Field exists but not maintained during commit.

Impact:

* Confusion over which balance is canonical

---

# 6. Balance Strategy Evaluation

Current strategy:

* Stored balance on accounts
* Incremental updates during commit
* Not recomputed per view

This is correct for production banking.

Recommendation:

* Treat Account.ledger_balance_cents as authoritative
* Either:

  * Remove running_balance_cents
  * Or compute it deterministically during commit

Do not support dual balance strategies.

---

# 7. CIF Assessment

CIF is intentionally lightweight and currently sufficient for:

* Single primary owner
* Basic ownership mapping
* Advisory linkage
* Account relationship listing

CIF does not yet support:

* Effective-dated ownership
* Guarantors
* Beneficial ownership
* Collateral
* Regulatory flags
* Risk aggregation

However, expanding CIF now would be premature until:

* Loan mechanics
* Accrual models
* Product structure
* Overdraft linkages

are defined.

---

# 8. Recommended Structural Hardening (Immediate)

1. Enforce single primary owner per account (application + DB approach)
2. Enforce single open teller session per user/workstation
3. Standardize canonical customer account reference format (e.g., acct:<account_number>)
4. Log warning or enforce presence of account_id on customer AccountTransactions
5. Document canonical posting reference patterns

---

# 9. Strategic Next Build Phase

## Phase 1 — Formalize Posting References

Introduce a first-class posting reference system to replace string-only references.

Goals:

* Typed references (customer, cash, income, expense, liability)
* GL classification support
* Referential integrity
* Trial balance foundation

This unlocks:

* Financial reporting
* Accrual automation
* Product-based accounting
* Regulatory defensibility

---

## Phase 2 — Account Type Framework

Replace hard-coded ACCOUNT_TYPES constant with:

* account_kinds table
* family classification (deposit, loan, core, non-ledger)
* ledger_behavior classification

Keep existing string during transition to avoid breaking flows.

---

## Phase 3 — Loan & Deposit Mechanics

Implement:

* Principal tracking
* Accrued interest tracking
* Payment allocation logic
* Overdraft link modeling
* Interest accrual job scaffold

Only after this should CIF expand further.

---

# 10. Risk Classification

| Area                      | Risk Level | Notes                            |
| ------------------------- | ---------- | -------------------------------- |
| Double-entry integrity    | Low        | Properly enforced                |
| Idempotency               | Low        | request_id uniqueness            |
| Cash controls             | Moderate   | Session exclusivity not enforced |
| Account ownership         | Moderate   | Primary not guaranteed           |
| Financial reporting       | High       | No typed GL reference layer      |
| Future accrual automation | High       | No formal ledger classification  |

---

# 11. Conclusion

BankCORE is structurally sound for:

* Teller operations
* Transaction posting
* Balance maintenance
* Operational audit

The system’s next architectural bottleneck is:

> Transitioning from string-based posting references to a structured ledger reference model.
