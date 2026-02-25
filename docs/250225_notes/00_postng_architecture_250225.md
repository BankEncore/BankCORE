# BankCORE Posting & Ledger Architecture (One-Page Reference)

## Purpose

Define the financial commit model used by BankCORE Teller operations.

This document describes how teller actions become:

* Immutable accounting records
* Customer ledger entries
* Physical cash movements

---

# 1. High-Level Model

```
TellerTransaction
        │
        ▼
PostingBatch (commit boundary)
        │
        ├── PostingLeg (immutable accounting truth)
        ├── AccountTransaction (ledger projection)
        └── CashMovement (physical drawer effect)
```

---

# 2. Layer Responsibilities

## 2.1 TellerTransaction — Operational Event

Represents a teller-originated financial event.

Stores:

* user_id
* teller_session_id
* branch_id
* workstation_id
* transaction_type
* amount_cents
* request_id (idempotency)
* posted_at

Does NOT store:

* debit/credit legs
* GL details
* running balances
* check breakdowns

**Purpose:** Operational wrapper and audit context.

---

## 2.2 PostingBatch — Financial Commit Container

Atomic financial commit unit (1:1 with TellerTransaction).

Stores:

* request_id (shared idempotency key)
* committed_at
* currency
* metadata (JSON workflow details)

Owns:

* posting_legs
* account_transactions

**Purpose:** Defines the immutable accounting commit boundary.

---

## 2.3 PostingLeg — Immutable Accounting Record

Canonical financial record.

Fields:

* posting_batch_id
* side ("debit" | "credit")
* account_reference (string placeholder)
* amount_cents (positive)
* position

Invariants:

* Total debits = total credits
* amount_cents > 0
* Immutable after commit
* Single currency per batch

**Purpose:** Core double-entry accounting truth.

Everything else derives from this.

---

## 2.4 AccountTransaction — Ledger Projection

1:1 projection of PostingLeg for ledger usage.

Adds:

* teller_transaction_id
* account_id (nullable; resolved from account_reference)
* direction (debit/credit)
* running_balance_cents (optional)

Resolution logic:

```
account_id = Account.find_by(account_number: account_reference)
```

If no match:

* account_id is null
* record still stored

**Purpose:**
Customer balance calculation and account history queries.

---

## 2.5 CashMovement — Physical Drawer Effect

Represents physical cash entering or leaving a drawer.

Created only if:

```
account_reference starts with "cash:"
```

Stores:

* teller_transaction_id
* teller_session_id
* cash_location_id
* direction ("in" | "out")
* amount_cents

At most:

* One CashMovement per teller transaction

**Purpose:** Drawer balancing and session control.

Not accounting. Not GL. Physical cash control only.

---

# 3. Account Reference Convention

PostingLeg uses string-based G/L placeholders:

| Prefix                    | Meaning                            |
| ------------------------- | ---------------------------------- |
| raw account number        | Customer deposit liability account |
| cash:CODE                 | Drawer/vault cash asset            |
| check:routing:acct:number | Check clearing placeholder         |
| income:...                | Revenue account                    |
| official_check:...        | Draft liability                    |

These are future GL mapping inputs.

---

# 4. Posting Flow

```
User Input
    │
    ▼
Posting::RecipeBuilder
    │
    ▼
Posting::Engine
    │
    ▼
Posting::Committer (DB transaction)
    │
    ├── Create TellerTransaction
    ├── Create PostingBatch
    ├── Create PostingLeg(s)
    ├── Create AccountTransaction(s)
    └── Record CashMovement (if applicable)
```

All operations occur inside a single database transaction.

---

# 5. Invariants

* One PostingBatch per TellerTransaction
* Shared request_id for idempotency
* PostingLeg is immutable
* Balanced debits and credits required before commit
* Single currency per batch
* CashMovement reflects physical drawer only
* AccountTransaction may exist without account_id

---

# 6. Design Principles

1. **Separation of concerns**

   * Operational event ≠ Accounting commit ≠ Ledger ≠ Cash control

2. **Immutable accounting**

   * PostingLeg is canonical and never mutated

3. **Derived projections**

   * Ledger and drawer effects derive from posting legs

4. **Idempotent engine**

   * request_id prevents duplicate financial commits

5. **GL-ready architecture**

   * account_reference designed for future GL mapping layer

---

# 7. Conceptual Summary

| Layer              | Purpose                  |
| ------------------ | ------------------------ |
| TellerTransaction  | Business event           |
| PostingBatch       | Commit boundary          |
| PostingLeg         | Double-entry truth       |
| AccountTransaction | Customer ledger view     |
| CashMovement       | Physical drawer movement |

**Core principle:**

> PostingLeg is the source of truth.
> Everything else is derived.

---

# 8. Regulatory Posture (Design Intent)

The architecture supports:

* Full audit traceability
* Immutable financial records
* Idempotent transaction processing
* Double-entry enforcement
* Physical cash segregation
* Clear separation between operational and accounting layers
