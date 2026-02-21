## L3-WF-01 — Approval Modal + Approval Window Lifecycle

**Status:** **Not aligned with current codebase**
**Current Implementation Mapping:** Approval modal exists and uses supervisor credentials + signed approval token via `POST /teller/approvals`; approval-window lifecycle and challenge binding model in this document are not implemented.
**Applies to:** reversals, vault transfer thresholds, large withdrawals, session close over/short, fee/overdraft overrides, etc.

---

# 1) Approval primitives

## 1.1 Approval event (per action)

Every approval-required action generates **one approval decision record**:

* approved / denied / cancelled
* individually timestamped
* individually audited

## 1.2 Approval window (5-minute supervisor window)

A short-lived supervisor-authenticated session scoped to:

* supervisor user
* teller user
* workstation
* branch
* teller_session

**Locked defaults**

* Duration: **5 minutes**
* Window re-use allowed
* Explicit confirmation required for each approval event
* Window invalidates on: lock, logout, session close, branch/workstation change, expiry

---

# 2) UI: Approval-required state (before modal)

When server indicates approval is required:

* Banner: neutral `APPROVAL REQUIRED`
* Post button stays enabled
* Clicking Post opens approval modal
* Form fields remain intact

**Focus behavior**

* Focus does not jump when banner appears
* When modal opens, focus moves into modal first field

---

# 3) Modal variants (two modes)

## 3.1 Mode A — No active window (authenticate + approve)

**Fields (tab order)**

1. Supervisor ID / Username
2. Supervisor Password
3. Optional Approval Note
4. Cancel
5. Authenticate & Approve

**Rules**

* Supervisor cannot equal initiating teller
* Supervisor must have approve permission for that approval_type

## 3.2 Mode B — Active window (confirm-only)

**Fields (tab order)**

1. Read-only supervisor identity + countdown timer
2. Optional Approval Note
3. Cancel
4. Approve This Action

No password field.

If the window expires while modal open:

* modal must transition back to Mode A (password required)

---

# 4) Server endpoints and request/response contract

## 4.1 Single approval endpoint

* `POST /teller/approvals`

### Request payload (minimum)

* `approval[approval_type]`
* `approval[approvable_type]`
* `approval[approvable_id]`
* `approval[idempotency_key]` *(ties approval to the pending post attempt)*
* `approval[reason_code]` *(if applicable; reversal always)*
* `approval[memo]` *(if applicable; reversal always)*
* `approval[note]` *(optional; supervisor note)*
* Mode A fields:

  * `supervisor[login]`
  * `supervisor[password]`
* Mode B fields:

  * `approval[window_confirm]=true`

### Server validation (mandatory)

* initiating teller present and authenticated
* teller_session open (for teller workflows)
* approvable exists and is eligible
* supervisor auth ok (Mode A) OR active window valid (Mode B)
* supervisor has permission
* supervisor != initiating teller

## 4.2 Response outcomes

### Approved (200)

Return Turbo Stream that:

1. Closes the modal
2. Marks the pending action as approved (server-side)
3. Proceeds to posting using the same `idempotency_key` *(see §5)*

### Denied (200)

* Re-render modal with error message
* Keep focus on first invalid field
* Do not clear main form

### Cancelled (200)

* Close modal
* Leave approval-required state in place
* Focus returns to Post button

---

# 5) Tying approval to posting (critical)

You must prevent “approval granted but different payload posted”.

**Contract rule:** Approval is granted for the specific **idempotency_key** of the pending post.

## Recommended implementation pattern

1. Teller clicks Post → server responds “approval required” and stores a pending “challenge” keyed by `idempotency_key` (can be session-backed for Phase 1).
2. Supervisor approves via modal → server records approval event and authorizes that `idempotency_key` to post.
3. Server immediately posts (same request cycle) OR returns a Turbo Stream instructing client to re-submit the original form with the same idempotency_key.

Either approach is valid; the invariant is: **approval must bind to the exact pending attempt**.

---

# 6) Logging requirements (schema-backed)

Using the approval tables we designed earlier:

## 6.1 Approval event fields (required)

* `approval_type`
* `status`
* `initiated_by_user_id`
* `approved_by_user_id` (if approved/denied)
* `approval_window_id` (if window used)
* `requested_at`
* `decided_at`
* `reason_code` + `memo` (where required)
* `amount_cents` (if relevant)
* `branch_id`, `workstation_id`, `teller_session_id`
* `context` JSON (optional but recommended)

## 6.2 Audit events (recommended, additional)

Also write `audit_events` rows:

* `approval.requested`
* `approval.approved`
* `approval.denied`
* `approval_window.opened`
* `approval_window.closed`

(Approvals table is authoritative; audit_events is the narrative log.)

---

# 7) Window lifecycle rules (server-authoritative)

## 7.1 Create window

On first successful supervisor authentication:

* create `approval_window`
* set `opened_at=now`, `expires_at=now+5min`

## 7.2 Reuse window

Window is reusable only if:

* `closed_at IS NULL`
* `expires_at > now`
* scope matches (supervisor/teller/workstation/session)

## 7.3 Close window

Window must be closed when:

* expired (background cleanup or on next check)
* workstation lock (WS-015)
* logout
* teller_session closed
* branch/workstation context changes
* explicit “End Supervisor Window” (optional UI)

---

# 8) UX: global indicator

When a window is active, Workstation header shows:

* `SUPERVISOR WINDOW ACTIVE (mm:ss)`

**Rules**

* display-only
* not tabbable
* disappears immediately when invalidated

---

# 9) Acceptance checklist

* [ ] All approvals use the same modal + endpoint
* [ ] Window reuse removes password but still requires explicit confirm
* [ ] Window expires and falls back to full auth
* [ ] Teller can’t self-approve
* [ ] Every approval decision is recorded as its own row
* [ ] Approval binds to idempotency_key to prevent payload swap
* [ ] Lock/logout/session close invalidate window immediately
* [ ] Denied/cancelled approvals do not clear form state
