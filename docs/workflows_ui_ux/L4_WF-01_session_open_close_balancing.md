## L4-WF-01 — Teller Session Open / Close (Balancing)

**Status:** **DROP-IN SAFE (schema-aligned)** — uses `teller_sessions` fields present in `schema.rb` (`status`, `opened_at`, `closed_at`, `opening_cash_cents`, `expected_closing_cash_cents`, `closing_cash_cents`, `cash_variance_cents`, `user_id`, `branch_id`, `workstation_id`, etc.).

---

# 1) Session invariants (must always hold)

## 1.1 One open session per user+workstation

At any time, a teller may have **at most one** open `teller_session` for the current workstation.

## 1.2 Session immutability after close

Once `teller_sessions.status` becomes `closed`:

* session totals are *never recomputed retroactively*
* later reversals and vault activity affect the **current open session**, not the closed one

## 1.3 Session is required for posting

All WS transactions that affect drawer/cash require:

* an **open** `teller_session` for `Current.user + Current.workstation`

---

# 2) WS-110 — Open Session

## 2.1 Routes

* `GET  /teller/session/open`
* `POST /teller/session/open`

## 2.2 Preconditions (blocking)

* Workstation context set (WS-005)
* Workstation not locked (WS-015)
* No existing open session for this user+workstation

If an open session already exists:

* redirect to WS-100 (Session Status) with banner: `BLOCKED: Session already open.`

## 2.3 Inputs (tab order)

1. Opening cash amount (`opening_cash_cents`) *(required; allow 0 only if policy allows)*
2. Notes (optional; if you have a column—if not, omit)
3. Cancel
4. Open Session

## 2.4 Approval triggers (optional but supported)

* opening amount above threshold
* after-hours
* teller role restricted

If approval required:

* `[APPROVAL REQUIRED]` state → approval modal
* window reuse allowed

## 2.5 Posting behavior

Opening a session is a **state transition event** and must be auditable.

On success, set:

* `status = "open"`
* `opened_at = now`
* `opening_cash_cents = <entered>`
* `branch_id`, `workstation_id`, `user_id` set from context

## 2.6 Receipt block

Show:

* Session ID
* Timestamp
* Teller / Branch / Workstation
* Opening cash

Actions:

* Print
* Go to Dashboard

---

# 3) WS-120 — Close Session (Balancing)

## 3.1 Routes

* `GET  /teller/session/close`
* `POST /teller/session/close`

## 3.2 Preconditions (blocking)

* Must have an open session for current user+workstation
* Workstation not locked

## 3.3 Close balancing calculation (authoritative)

Server computes:

* `expected_closing_cash_cents` based on all posted cash-impacting events in the session (deposit cash in, withdrawal cash out, vault in/out, check cashing cash out, fees if cash, etc.)
* Teller enters `closing_cash_cents` (counted)
* `cash_variance_cents = closing_cash_cents - expected_closing_cash_cents`

> UI may display live projections, but the server value is authoritative.

## 3.4 Inputs (tab order)

1. Counted cash amount (`closing_cash_cents`) *(required)*
2. Optional notes (if supported)
3. Cancel
4. Close Session

## 3.5 Approval triggers (required when tolerance exceeded)

If `abs(cash_variance_cents) > tolerance_cents`:

* approval required (mandatory)
* supervisor window reuse allowed
* approval record must include variance amount and tolerance in context JSON

If within tolerance:

* close allowed without approval

## 3.6 Close posting

On successful close:

* `status = "closed"`
* `closed_at = now`
* set computed fields:

  * `expected_closing_cash_cents`
  * `closing_cash_cents`
  * `cash_variance_cents`

Hard rule:

* after close, no further postings may attach to this session.

## 3.7 Receipt block (close report)

Show:

* Session ID
* Opened/closed timestamps
* Opening cash
* Expected closing cash
* Counted closing cash
* Over/short amount (variance)
* Supervisor stamp if approval used

Actions:

* Print Close Report
* Return to Dashboard

---

# 4) Interaction with approvals + approval window

## 4.1 Closing a session invalidates approval window

On session close:

* approval window must be closed with reason `session_closed`

## 4.2 Approval event typing

For session close variance approval:

* `approval_type = "session_close_over_short"`
* `amount_cents = cash_variance_cents.abs` (or store signed in context)
* `context` includes:

  * expected
  * counted
  * variance
  * tolerance

---

# 5) Edge cases you must define now

## 5.1 Session close with pending draft transaction UI open

If teller attempts to close while a transaction form is mid-edit:

* block close with banner: `BLOCKED: Finish or cancel the current transaction before closing the session.`

(Keep this simple for Phase 1. Avoid “auto-cancel” on close.)

## 5.2 Network retry / double-submit

Session open and close must use idempotency keys (same contract as transaction posting).

* double POST should not create two sessions or double-close

## 5.3 Multiple open sessions detected

If DB ever has two open sessions for same user+workstation:

* SYSTEM ERROR banner
* block transactions and closing
* require supervisor/Ops intervention (OPS-020/030)

---

# 6) Acceptance checklist

* [ ] WS-110 cannot open if open session already exists
* [ ] WS-120 cannot close if no open session exists
* [ ] Expected cash is computed server-side and stored
* [ ] Counted cash entered; variance computed and stored
* [ ] Approval required when variance exceeds tolerance
* [ ] Closing sets `status=closed` and `closed_at` and freezes session
* [ ] Reversals after close post to the current open session (not the closed one)
* [ ] Session close invalidates approval window
* [ ] Open/Close produce receipt blocks with Print + Next action

-