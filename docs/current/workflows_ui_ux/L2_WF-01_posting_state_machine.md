## L2-WF-01 — Posting & State Machine (Global)

**Status:** **Fits but needs working changes** — lifecycle model mostly matches implemented UX, but this doc includes unimplemented workflows (reversal/vault/draft/bill/misc).
**Current Implementation Mapping:** Implemented postable workflows are Deposit, Withdrawal (cash), Transfer, and Check Cashing via `/teller/posting` + `/teller/transactions/validate` + `/teller/approvals`.
**Goal:** Every financial action follows a single, deterministic lifecycle that is UI-consistent, idempotent, and audit-defensible.

> Note: some earlier conceptual docs you uploaded have expired; `schema.rb` is present now, so this contract is based on that.

---

# 1) Canonical lifecycle states

All postable workflows (Deposit/Withdrawal/Transfer/Check Cashing/Draft/Bill Pay/Misc Receipt/Vault Transfer/Reversal) use the same lifecycle:

1. **Editing**
2. **Validating**
3. **Approval Required** *(optional state)*
4. **Posting**
5. **Posted**
6. **Reset** *(manual reset; returns to Editing)*

**Non-negotiable:** no workflow may “skip” to Posted without entering Posting.

---

# 2) What constitutes a “postable action” in Phase 1

A postable action is any workflow that results in:

* a `TellerTransaction` row **and**
* a `PostingBatch` row with entries/lines (double-entry)

Includes:

* WS-120 Session Close (balancing close as a postable event)
* WS-300 Vault Transfer
* WS-040 Reversal (always)

---

# 3) UI contract per state

## 3.1 Editing

* Entry form inputs enabled
* Totals live-update (client-side) but server remains authoritative
* Post button enabled/disabled based on local validation + balance status
* Cancel enabled

## 3.2 Validating (pre-post gate)

Triggered by clicking Post / Ctrl+Enter.

* Run client-side validation first (required fields, format)
* Submit to server for authoritative validation (limits, account status, session status, etc.)
* If server responds with blocking validation errors:

  * remain in Editing
  * focus first invalid field
  * show blocking banner + field errors

## 3.3 Approval Required

If server indicates approval required OR client policy triggers it:

* Show neutral badge: `[ APPROVAL REQUIRED ]`
* Keep Post enabled
* Clicking Post opens approval modal
* Form state must be preserved; no fields cleared

**Important:** approval is not an error state.

## 3.4 Posting

Once server accepts and (if required) approval is granted:

* Disable Post + Cancel
* Make inputs read-only (or disable)
* Show badge: `[ POSTING ]`
* Prevent mode switches, lock, nav changes (or require hard confirm if you allow lock)

## 3.5 Posted

On success:

* Replace entry form with **Receipt Block**
* Focus lands on: **New <Transaction>**
* Only actions are:

  * Print Receipt
  * New <Transaction>

## 3.6 Reset (manual)

* New <Transaction> clears form
* Returns to Editing
* Focus returns to first field

---

# 4) Server-side posting model (authoritative)

## 4.1 Required atomicity

A post is **one atomic unit**:

* Create `teller_transactions` record
* Create `posting_batches` record
* Create `posting_entries` and `posting_lines` (balanced)
* Update any derived session totals (if you do so)
* Emit `audit_events`

All in one DB transaction.

## 4.2 Idempotency / double-post prevention

Every post request must include an **idempotency key**.

Recommended mechanism (drop-in):

* client generates a UUID per attempted post, send as `request_id`
* server enforces: “only one posting batch per idempotency key”

Implementation options:

* If you already have a `request_id` column on `posting_batches` or `teller_transactions`, reuse it
* If not present, add:

  * `teller_transactions.request_id` (string, indexed unique)
  * or `posting_batches.request_id` (string, indexed unique)

**Behavior:**

* If the same idempotency key is replayed (double click, refresh, retry):

  * server returns the already-created posted result (receipt) without creating duplicates

---

# 5) Balance enforcement (double-entry integrity)

## 5.1 Required invariant

Every posting batch must be balanced:

* Sum(debits) == Sum(credits)

Enforce at service layer prior to commit; optionally add DB-level check later if practical.

## 5.2 Teller UI status mapping

* If client totals show out-of-balance:

  * Post disabled (blocking)
* If server finds out-of-balance:

  * return SYSTEM ERROR (blocking), because this is a programming defect

---

# 6) Error model mapping (global)

All workflows must map to these outcomes:

## 6.1 Blocking validation errors

Examples:

* missing required field
* invalid amount
* no open teller session
* account not found
* insufficient funds (if not overridable)

UI:

* Blocking banner + inline field errors
* Stay in Editing; focus first invalid

## 6.2 Approval required

Examples:

* threshold exceeded
* reversal (always)
* vault transfer over limit
* session close variance over tolerance

UI:

* Neutral badge
* Post triggers modal

## 6.3 Warning (non-blocking)

Examples:

* large transaction advisory
* unusual pattern note

UI:

* Yellow banner
* Post allowed

## 6.4 System error

Examples:

* posting batch failed to persist
* line generation mismatch
* multiple open sessions detected
* stale lock/context mismatch

UI:

* Red SYSTEM banner
* Post disabled
* Provide safe recovery path (Back to Dashboard)

---

# 7) Receipt block contract (post success)

Receipt must include, at minimum:

* Reference #
* Server timestamp
* Teller/session/workstation/branch
* Transaction type
* Financial breakdown (legs summary)
* Drawer impact (if applicable)
* Approval metadata (if approval was used):

  * supervisor id
  * whether window used (optional display; required in audit)

---

# 8) Cross-workflow specializations (still same state machine)

## 8.1 WS-120 Close Session

* Close is a postable event
* Must compute expected vs counted
* If variance over tolerance → Approval Required
* Posted state shows close receipt (print + return dashboard)

## 8.2 WS-040 Reversal

* Always Approval Required
* Always creates new teller_transaction + new posting batch
* Must link original ↔ reversal

## 8.3 WS-300 Vault Transfer

* Reason code required
* Approval conditional (threshold + certain reasons)
* Drawer impact must be shown and posted

---

# 9) Acceptance checklist

* [ ] All postable workflows implement the same lifecycle states
* [ ] Post is atomic (teller_transaction + posting_batch + lines)
* [ ] Idempotency prevents double-post duplicates
* [ ] Approval required state is neutral and consistent
* [ ] Posting state disables inputs and prevents navigation/mode switches
* [ ] Receipt replaces form; manual reset only
* [ ] Out-of-balance cannot be posted (client blocks; server asserts)
* [ ] System errors are distinguishable from validation errors
* [ ] Audit events emitted for post + approval + session events

