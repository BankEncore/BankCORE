---
status: considering
category: considering
updated: 2026-03-01
---

# Stimulus Event Matrix Handoff (Teller Transaction UX)

## 1) Purpose
Define the current-to-target Stimulus event contract for teller transaction UX so we can migrate from monolithic form orchestration to explicit transaction shell ownership without breaking existing server contracts.

Scope is limited to these existing endpoints:
- `POST /teller/transactions/validate`
- `POST /teller/approvals`
- `POST /teller/posting`
- `GET /teller/receipts/:request_id`

Current transaction types (implemented): **deposit, withdrawal, transfer, check_cashing, draft, vault_transfer, misc_receipt**.  
Planned transaction types (not implemented): **bill_payment**.

---

## 2) Controller ownership map (current vs target)

| Concern | Current Owner | Target Owner | Migration Note |
|---|---|---|---|
| UI state (`editing`, `validating`, `approval required`, `posting`, `posted`, `blocked`) | `posting_form_controller` | `tx_shell_controller` | Move state machine first; keep legacy events until PR4. |
| Keyboard shortcuts / submit intent | implicit in form interactions | `tx_keyboard_controller` | Add keyboard intent events; no direct posting calls. |
| Client-side totals, balance, blocked reason | `posting_form_controller` | `tx_validation_controller` | Split pure calc/guard logic from shell. |
| Dynamic line item rows (checks) | `line_items_controller` | `line_items_controller` (+ emits normalized events) | Keep controller, change event shape only. |
| Reference panel refresh + account snapshots | `reference_panel_controller` | `reference_panel_controller` (consumes shell-level events) | Keep endpoint usage; decouple from posting form internals. |
| Approval panel show/request/hide | `approval_panel_controller` + `posting_form_controller` handlers | `approval_panel_controller` + `tx_shell_controller` | Shell owns approval state; panel owns credentials UX. |
| Validate API call | `posting_form_controller` | `tx_validation_controller` | Endpoint remains `POST /teller/transactions/validate`. |
| Posting API call | `posting_form_controller` | `tx_posting_controller` | Endpoint remains `POST /teller/posting`. |
| Receipt reveal / link binding | `posting_form_controller` | `tx_receipt_controller` | Receipt load/view remains `GET /teller/receipts/:request_id`. |

---

## 3) Event matrix

| Event | Emitted By | Consumed By | Payload | Guard Conditions | State Transition | Notes |
|---|---|---|---|---|---|---|
| `tx:changed` (existing) | `line_items_controller` | `posting_form_controller` (current), `tx_validation_controller` (target) | none | Any line item add/remove | `editing -> editing` (recompute) | Keep in PR1 for compatibility. |
| `tx:recalc` (existing) | `posting_form_controller` (current), `tx_validation_controller` (target) | `reference_panel_controller`, `tx_shell_controller` | `transactionType`, `entries`, `primaryReference`, `counterpartyReference`, `cashReference`, `requestId`, `cashAmountCents`, `checkAmountCents`, `feeCents`, `checkSubtotalCents`, `totalAmountCents`, `debitTotal`, `creditTotal`, `imbalanceCents`, `cashImpactCents`, `projectedDrawerCents`, `readyToPost`, `blockedReason` | Form data present | `editing -> editing` | Reference panel should consume this as read-only context event. |
| `tx:approval-required` (existing) | `posting_form_controller` (after validate response) | `approval_panel_controller`, `tx_shell_controller` | `reason`, `policyTrigger`, `policyContext` | Validate response has `approval_required=true` and no token | `validating -> approval_required` | Triggered from `POST /teller/transactions/validate`. |
| `tx:approval-granted` (existing) | `approval_panel_controller` | `posting_form_controller` (current), `tx_shell_controller` (target) | `approvalToken` | `POST /teller/approvals` returns `ok=true` | `approval_required -> editing/ready_to_post` | Shell should store token and re-enable post path. |
| `tx:approval-error` (existing) | `approval_panel_controller` | `posting_form_controller` (current), `tx_shell_controller` (target) | `message` | Missing request ID, auth failure, network failure | `approval_required -> blocked` (or remain with error banner) | Keep non-destructive; do not clear form. |
| `tx:approval-cleared` (existing) | `posting_form_controller` (reset/post-success clear) | `approval_panel_controller`, `tx_shell_controller` | none | Reset/new transaction or successful post cleanup | `posted -> editing` | Must hide approval UI and clear token state. |
| `tx:validate-requested` (proposed) | `tx_shell_controller` | `tx_validation_controller` | serialized transaction payload + `requestId` | Post intent and local guards pass | `editing -> validating` | Explicit ownership split for validate call. |
| `tx:validated` (proposed) | `tx_validation_controller` | `tx_shell_controller`, `tx_posting_controller` | `{ ok, approval_required, errors, warnings, approval_reason, approval_policy_trigger, approval_policy_context }` | Response from `POST /teller/transactions/validate` | `validating -> ready_to_post` or `approval_required` or `blocked` | Canonical server-validation result event. |
| `tx:post-requested` (proposed) | `tx_shell_controller` | `tx_posting_controller` | posting payload + `approvalToken` + `requestId` | `ready_to_post`, not posting | `ready_to_post -> posting` | Prevent duplicate posts while in-flight. |
| `tx:posted` (proposed) | `tx_posting_controller` | `tx_shell_controller`, `tx_receipt_controller` | `postingBatchId`, `tellerTransactionId`, `requestId`, `postedAt` | `POST /teller/posting` success (`ok=true`) | `posting -> posted` | Receipt controller maps to `/teller/receipts/:request_id`. |
| `tx:post-failed` (proposed) | `tx_posting_controller` | `tx_shell_controller` | `error`, optional `code` | posting response not ok / network fail | `posting -> blocked` | Preserve entered data; allow retry after correction. |
| `tx:receipt-ready` (proposed) | `tx_receipt_controller` | `tx_shell_controller` | `receiptUrl`, `requestId` | `tx:posted` received | `posted -> posted` | UI-only completion signal for receipt section/link. |

---

## 4) Migration phases (PR1..PR6)

| PR | Ownership Change | Event Changes | Endpoint Touchpoints |
|---|---|---|---|
| **PR1** | Baseline contract freeze on current controllers | Document and assert existing events: `tx:changed`, `tx:recalc`, `tx:approval-required`, `tx:approval-granted`, `tx:approval-error`, `tx:approval-cleared` | Confirm unchanged behavior for validate/approval/posting/receipt endpoints. |
| **PR2** | Introduce `tx_shell_controller` (state only), keep `posting_form_controller` as executor | Add proposed shell events (`tx:validate-requested`, `tx:post-requested`) while still forwarding to existing handlers | No server changes; shell orchestrates around current calls. |
| **PR3** | Move validation logic/API to `tx_validation_controller` | Emit `tx:validated`; keep compatibility emission of `tx:approval-required` | `POST /teller/transactions/validate` now called by validation controller. |
| **PR4** | Move posting API to `tx_posting_controller`; move receipt bind to `tx_receipt_controller` | Emit `tx:posted` / `tx:post-failed` / `tx:receipt-ready`; deprecate direct receipt handling in posting form | `POST /teller/posting`, `GET /teller/receipts/:request_id`. |
| **PR5** | Reduce `posting_form_controller` to field adapter; shell owns all state transitions | `posting_form_controller` stops owning approval/posting states; approval handled through shell + panel | `POST /teller/approvals` flow unchanged, ownership changed. |
| **PR6** | Remove legacy state/event paths from `posting_form_controller` | Remove legacy consumers of approval/post events; keep only stable event bus contracts | Finalize for existing types; scaffold extensibility for planned types. |

---

## 5) Risks and anti-patterns to avoid
- Do not let multiple controllers own the same state flag (`ready_to_post`, `posting`, `approval_required`).
- Do not call endpoints directly from more than one controller per concern (single owner per endpoint intent).
- Do not break existing `tx:*` events before target consumers are live (maintain compatibility window PR2–PR4).
- Do not clear form data on validate/approval/post failures (non-destructive workflow requirement).
- Do not couple reference panel rendering to form DOM internals; consume normalized event payload only.
- Do not introduce transaction-type branching in multiple controllers; centralize gating rules in validation/shell.
- Do not treat planned types as active routes until endpoints/controllers exist.

---

## 6) Test checklist (system/controller behaviors)

### Controller-level (existing + expanded)
- `POST /teller/transactions/validate`:
  - returns `ok=true` for balanced payloads
  - returns `approval_required=true` for threshold conditions
  - returns totals/imbalance contract used by `tx:validated`/`tx:recalc`
- `POST /teller/approvals`:
  - returns `approval_token` for valid supervisor credentials
  - returns unauthorized for invalid credentials
  - preserves policy trigger/context in audit metadata
- `POST /teller/posting`:
  - creates one posting batch + teller transaction per new `request_id`
  - remains idempotent for duplicate `request_id`
  - returns error for unbalanced payloads
- `GET /teller/receipts/:request_id`:
  - renders receipt/audit view for posted transaction
  - renders check-cashing metadata when transaction type is `check_cashing`

### System behavior (add during migration)
- Event flow:
  - field/line-item change emits recalc and updates readiness badge/reason
  - validate intent transitions `editing -> validating -> (ready|approval_required|blocked)`
  - approval grant transitions back to postable state without data loss
  - post success transitions `posting -> posted`, binds receipt link with request id
- Guard behavior:
  - post disabled when blocked reason exists, imbalance exists, or missing required references
  - duplicate submit while `posting` is in-flight is ignored
- Cross-type smoke:
  - implemented types (`deposit`, `withdrawal`, `transfer`, `check_cashing`) follow same state machine
  - planned types are not exposed as active posting paths until explicitly implemented.
