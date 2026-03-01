Below is a **focused integrity audit** of your Posting & Ledger architecture as described in .

This is not stylistic feedback — only structural, financial, and regulatory integrity risks.

---

# Executive Summary

Your architecture is structurally strong and regulator-aligned.

However, there are **6 areas of integrity exposure** that should be addressed before calling this production-grade core posting infrastructure:

1. Balance enforcement location
2. Referential drift risk (`account_reference` string-based model)
3. Running balance correctness model
4. Immutability enforcement guarantees
5. Idempotency race conditions
6. CashMovement derivation assumptions

None of these are fatal flaws — but each is important.

---

# 1️⃣ Balance Enforcement Risk

### Current Model

You enforce:

> total debits = total credits before commit

### Risk

If balance validation exists only in:

* RecipeBuilder
* Engine pre-check

… and not at database level, then corruption could occur via:

* Direct model calls
* Console scripts
* Background jobs
* Future refactors

### Integrity Concern

There is no DB-level constraint ensuring balanced PostingLeg totals.

### Recommendation (High Priority)

Add a database-enforced balance check at the batch level:

Options:

**Option A — Deferred DB constraint**

* Use a trigger to validate batch totals before commit.

**Option B — Locked engine commit**

* Perform balance check inside the same DB transaction immediately before persist.
* Fail hard if mismatch.

This is core accounting integrity.

---

# 2️⃣ `account_reference` String-Based Resolution Risk

### Current Behavior

```ruby
account_id = Account.find_by(account_number: account_reference)
```

### Risks

1. Account numbers can change (if ever allowed)
2. No FK integrity between PostingLeg and Account
3. Typo in account_reference silently creates orphan ledger lines
4. Case sensitivity / formatting drift

### Structural Exposure

PostingLeg uses:

* string-based reference
* no referential enforcement

This is flexible — but introduces long-term data drift risk.

### Recommendation (Medium Priority)

At minimum:

* Enforce canonical format for account_reference
* Normalize casing
* Add format validations by prefix
* Disallow account number edits after creation

Long-term (Phase 2+):

* Consider storing `account_id` alongside account_reference in PostingLeg if resolved at commit time.

---

# 3️⃣ Running Balance Integrity Risk

You mention:

```
running_balance_cents (optional)
```

If running balance is stored:

### Risk

* Race conditions
* Historical recalculation inconsistencies
* Retroactive adjustments corrupt balances
* Manual inserts break ordering

If running balance is computed incrementally:
You must enforce:

* Deterministic ordering
* Single-writer guarantee
* No historical inserts allowed

### Recommendation (High Priority if using stored balances)

Either:

A) Do NOT store running balance — compute from sum
OR
B) Enforce strict chronological locking model per account

This is a common source of silent corruption in financial systems.

---

# 4️⃣ Immutability Enforcement Gap

You state:

> PostingLeg is immutable

But:

Is it technically immutable?

### Risks

* Rails console updates
* Admin scripts
* Mass assignment
* No DB constraint preventing updates

### Recommendation (Critical for audit defensibility)

Enforce immutability at DB level:

Options:

* Add DB trigger preventing UPDATE/DELETE on posting_legs
* Or soft-lock via status column
* Or remove update routes entirely

True immutability must be enforced outside Rails validations.

---

# 5️⃣ Idempotency Race Condition Risk

You rely on:

```
request_id (unique)
```

If two requests hit simultaneously:

* Engine checks for existing batch
* Both see none
* Both attempt create

If not transactionally locked:

→ duplicate commit possible before unique index throws error

### Recommendation (High Priority)

Ensure:

* Unique DB index on request_id (you have this)
* Entire commit wrapped in DB transaction
* Rescue unique constraint error and reload existing batch

Idempotency must be safe under concurrency.

---

# 6️⃣ CashMovement Derivation Risk

Current logic:

```
Filter legs with account_reference.start_with?("cash:")
Determine direction
Sum
Create one CashMovement
```

### Risks

1. Assumes one drawer per session
2. Assumes no split cash movements
3. Relies on prefix naming convention
4. Fails silently if prefix changes

### Recommendation (Medium Priority)

* Validate exactly one drawer reference per transaction (except vault)
* Assert zero or one drawer-involving legs
* Fail if conflicting cash legs detected

Drawer integrity is audit-sensitive.

---

# 7️⃣ Metadata Integrity Risk

PostingBatch.metadata is JSON.

Risks:

* Schema drift
* Missing required keys
* Backward compatibility breakage
* Regulatory reporting inconsistency

Recommendation:

* Validate metadata shape per transaction_type
* Consider JSON schema validation at commit time

---

# 8️⃣ Missing Explicit Reversal Model

Currently:

* No reversal table
* No reversal relationship model

Risk:
Manual reversals may:

* Create accounting drift
* Break running balances
* Break audit trails

Recommendation:
Introduce:

```
reversal_of_posting_batch_id
```

Or:

```
reversal_transaction_id
```

Reversals should be explicit, not ad hoc negative postings.

---

# 9️⃣ Referential Integrity Between Layers

Currently:

PostingLeg → posting_batch_id
AccountTransaction → teller_transaction_id, posting_batch_id
CashMovement → teller_transaction_id

Ensure:

* All FKs are NOT NULL (where expected)
* All FKs have ON DELETE RESTRICT

Financial records should never cascade delete.

---

# 10️⃣ What You Did Very Well

These are strengths:

* Idempotent engine
* Explicit commit boundary
* Double-entry enforced pre-persist
* Cash isolated from ledger
* Metadata per workflow
* Clear separation of concerns
* Prefix namespace for GL placeholder
* 1:1 leg → ledger mapping

Architecturally this is far more disciplined than most early cores.

---

# Overall Risk Rating

| Area                      | Risk Level       |
| ------------------------- | ---------------- |
| Balance enforcement       | Medium           |
| Referential drift         | Medium           |
| Running balance           | High (if stored) |
| Immutability enforcement  | High             |
| Idempotency concurrency   | Medium           |
| Cash movement assumptions | Medium           |

Overall system integrity: **Strong foundation, needs hardening.**

---

# If You Want a Production-Grade Core

The 4 upgrades that would elevate this to bank-grade defensibility:

1. DB-level immutability enforcement
2. DB-enforced idempotency handling logic
3. Running balance model formalization
4. Explicit reversal architecture

---

If you’d like, next I can:

* Draft DB-level integrity hardening patterns
* Draft a regulator-style internal control narrative
* Or map this to FFIEC-style expectations
* Or create a “Financial Integrity Hardening Roadmap” document

This architecture is very close to being institution-grade — it just needs defensive reinforcement.
