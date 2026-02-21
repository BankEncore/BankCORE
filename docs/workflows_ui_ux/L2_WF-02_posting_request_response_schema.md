## L2-WF-02 — Posting Request/Response Contract (UI ↔ Server)

**Status:** **DROP-IN SAFE (schema-aligned)** for BankCORE Phase 1, using your existing teller + posting tables and the approval-window model we locked.

This contract standardizes **how every WS post** (deposit/withdrawal/etc., vault transfer, reversal, session close) is submitted and how the server responds.

---

# 1) Transport and rendering model (Turbo-first)

## 1.1 Form submission

* Each WS workflow uses a normal HTML `<form method="post">`
* Submit via:

  * Click **Post**
  * `Ctrl+Enter` triggers `.requestSubmit()`

## 1.2 Rendering targets

Use Turbo Frames to keep the shell stable:

* `turbo-frame id="tx_form"` — entry form + inline field errors + approval state
* `turbo-frame id="tx_receipt"` — receipt block (empty until posted)
* `turbo-frame id="tx_banners"` — banner region (blocking/warning/system/approval notice)
* Optional: `turbo-frame id="tx_reference"` and `tx_totals` if you want partial updates

**Rule:** On success, server replaces `tx_form` with receipt block **or** swaps visibility (but end result must match the Posted state contract).

---

# 2) Required request fields (all postable workflows)

## 2.1 Idempotency

Every post request must include:

* `idempotency_key` (UUID string)

Generation:

* created when the form first loads
* regenerated when user clicks “New <Transaction>”

Server behavior:

* same idempotency key must never create two posted results

## 2.2 Context assertions (hidden fields)

To prevent cross-context posting:

* `branch_id`
* `workstation_id`
* `teller_session_id`

Server must verify these match `Current.*`.

---

# 3) Standard request shapes (examples)

## 3.1 Deposit (example payload)

* `deposit[account_id]`
* `deposit[cash_amount_cents]`
* `deposit[checks][][routing]`
* `deposit[checks][][account]`
* `deposit[checks][][check_number]`
* `deposit[checks][][amount_cents]`
* `deposit[checks][][hold_enabled]`
* `deposit[checks][][hold_reason]`
* `idempotency_key`, `branch_id`, `workstation_id`, `teller_session_id`

## 3.2 Vault transfer (example)

* `vault_transfer[direction]` (`drawer_to_vault` / `vault_to_drawer`)
* `vault_transfer[amount_cents]`
* `vault_transfer[reason_code]` (required)
* `vault_transfer[memo]`
* plus idempotency + context assertions

## 3.3 Reversal (example)

* `reversal[original_teller_transaction_id]`
* `reversal[reason_code]` (required)
* `reversal[memo]` (required)
* plus idempotency + context assertions

---

# 4) Response categories (server → UI)

Each POST must return **one** of these outcomes.

## 4.1 Blocking validation errors (HTTP 422)

Examples:

* missing required field
* amount ≤ 0
* no open teller session
* invalid account
* ineligible reversal

**Response:**

* Turbo render updates:

  * `tx_banners` with BLOCKED banner
  * `tx_form` with inline field errors
* Focus rule: client-side (Stimulus) focuses first invalid field after render

## 4.2 Approval required (HTTP 200)

Server indicates approval is required but does **not** post.

**Response:**

* `tx_banners` shows neutral `[APPROVAL REQUIRED]`
* `tx_form` re-renders with a hidden “approval required” flag and whatever policy message is needed
* Post button remains enabled; next Post opens modal

## 4.3 Approval denied (HTTP 200)

Approval modal submitted but supervisor denied / invalid password.

**Response:**

* `tx_banners` shows neutral “Approval denied” notice (not red)
* `tx_form` remains intact (no clearing)
* Focus rule: return focus to Post

## 4.4 System error (HTTP 500 or 200 with system banner; prefer 500)

Examples:

* posting batch generation mismatch
* idempotency conflict you can’t reconcile
* multiple open sessions detected
* DB transaction failed

**Response:**

* `tx_banners` shows SYSTEM ERROR banner
* `tx_form` rendered in disabled state (or with Post disabled)
* Provide safe action: “Back to Dashboard”

---

# 5) Approval modal request/response (standardized)

## 5.1 Request

Approval modal posts to a single endpoint:

* `POST /teller/approvals`

Payload includes:

* `approval[approval_type]`
* `approval[approvable_type]`
* `approval[approvable_id]`
* `approval[reason_code]` (if applicable)
* `approval[memo]` (if required)
* `approval[idempotency_key]` (tie to the pending post)
* Supervisor credentials OR window-confirm token:

  * If no active window: `supervisor[user_id]` + `supervisor[password]`
  * If window active: `approval[window_confirm]=true`

## 5.2 Response

* Success: returns Turbo stream that:

  * closes modal
  * triggers the original post to proceed (either via redirect to POST action continuation or via a “finalize post” endpoint)
* Failure: re-render modal with field error; keep focus in modal

**Important:** The approval window is server-authoritative; UI only displays countdown.

---

# 6) Success response (Posted) — standardized receipt swap

On successful post (HTTP 200 or 303 → GET receipt view):

Server must render:

* Receipt block content with reference #
* “Print Receipt”
* “New <Transaction>”

Turbo updates:

* Replace `tx_form` with receipt block **or**
* Replace `tx_receipt` and hide `tx_form` (either is fine, but must be consistent system-wide)

Focus:

* client focuses “New <Transaction>” after render

---

# 7) Idempotency response behavior (critical)

If the server receives a POST with an idempotency key that already posted:

* Return the existing receipt state (Posted)
* Do not create new teller_transaction or posting_batch
* UI sees “Posted” response and displays receipt

This prevents double-click duplicates and refresh retries from creating extra postings.

---

# 8) Redirect rules (allowed but constrained)

* Use 303 redirects only for:

  * after successful post → `GET /teller/transactions/:id/receipt`
* Never redirect on validation errors (must render in place)
* Never redirect during approval required (must remain on same screen)

---

# 9) Acceptance checklist

* [ ] Every WS post includes `idempotency_key` + context assertions
* [ ] 422 used for validation errors and re-renders form in place
* [ ] Approval required returns 200 with approval state, no posting
* [ ] Approval modal uses a single endpoint and supports window reuse
* [ ] Success swaps to receipt with Print + New actions only
* [ ] Replayed idempotency key returns existing receipt (no duplicates)
* [ ] Focus behavior matches UI contract after each response type
