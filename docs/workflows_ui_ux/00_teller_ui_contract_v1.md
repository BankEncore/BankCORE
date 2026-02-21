# 1) Versioned Governance Artifact

**File:** `docs/workflows_ui_ux/00_teller_ui_contract_v1.md`
**Status:** **Target contract (Phase 1 direction, partially implemented)**
**Style:** Traditional Workstation, browser-safe, keyboard-first.

## 0.1 Implementation Mapping (Proposed Scope → Current BankCORE)

| Contract Scope Item | Current Endpoint(s) | Implementation |
|---|---|---|
| Deposit | `GET /teller/transactions/deposit`, `POST /teller/posting` | Implemented |
| Withdrawal (cash flow) | `GET /teller/transactions/withdrawal`, `POST /teller/posting` | Implemented |
| Transfer | `GET /teller/transactions/transfer`, `POST /teller/posting` | Implemented |
| Check Cashing | `GET /teller/transactions/check_cashing`, `POST /teller/posting` | Implemented |
| Draft Issuance | — | Planned |
| Bill Payment | — | Planned |
| Misc Receipt | — | Planned |
| Vault Transfer | — | Planned |
| Validation API | `POST /teller/transactions/validate` | Implemented |
| Approval API | `POST /teller/approvals` | Implemented (token-based approval) |
| Receipt viewer | `GET /teller/receipts/:request_id` | Implemented |

## 0.2 Contract usage rule

- Treat this document as the target UX contract for incremental delivery.
- If a section references a Planned surface, mark implementation tasks against the endpoint mapping above before enforcing as mandatory behavior.

## 1. Scope

Applies to teller-facing transaction workflows:

* Deposit, Withdrawal, Transfer
* Check Cashing, Draft Issuance, Bill Payment, Misc Receipt, Vault Transfer

Does not cover:

* CIF maintenance screens
* Back-office/admin
* Reporting/analytics pages

## 2. Non-Negotiables

* No mid-transaction reloads or redirects
* No destructive validation (never clears entered data)
* Post disabled when out-of-balance, blocked, posting, or system error
* Approval is non-destructive and modal-based
* Manual reset after post (no auto-reset timers)
* Command bar and top context bar are **not** in tab order
* Tab order applies only to active transaction form

## 3. Required Screen Skeleton (All Transactions)

**Zones (top to bottom):**

1. Top Context Bar (display-only)
2. Command Bar (visible + clickable + F-key; `tabindex=-1`)
3. Header (title + state + actions hint)
4. Error Banner Region
5. Main Body: Entry Form (left) + Reference Panel(s) (right)
6. Totals Panel (read-only)
7. Drawer Footer (read-only; “NO CASH MOVEMENT” where applicable)
8. Approval Modal (when required)

## 4. Navigation Contract

* Command bar shows F-key mapping: **F2–F4, F6–F10**
* Switching modes:

  * If pristine: switch immediately
  * If dirty: confirm “Stay” vs “Cancel & Switch”

## 5. Keyboard Contract (Minimal v1)

* **F2/F3/F4/F6/F7/F8/F9/F10**: mode switches
* **Esc**: cancel / close modal (confirm if dirty)
* **Ctrl+Enter**: attempt post
* Do not map F5/F11/F12 and do not override browser-reserved Ctrl shortcuts.

## 6. Tab Scope Contract

* Tab/Shift+Tab affects **only the active transaction form inputs and in-form buttons**
* Command bar buttons: native `<button>`, but **`tabindex="-1"`**
* Top context bar: display-only, no interactive elements
* Reference panels, totals, drawer footer: non-tabbable

## 7. Per-Transaction Tab Contracts

* Deposit, Withdrawal, Transfer tab orders are **fixed** (as previously locked).
* Dynamic rows:

  * Add focuses first field of new row
  * Remove focuses next logical field (neighbor row or Add button)

## 8. Focus Recovery Contract (Global)

* Post success → receipt block → focus **New <Transaction>**
* Cancel confirm → reset → focus first field
* Cancel deny → focus Cancel
* Validation errors → focus first invalid field
* Approval modal close → focus Post
* Toggle progressive disclosure:

  * expand → focus first field
  * collapse while focused inside → focus toggle

## 9. Posting + Receipt Contract (Manual Reset)

* Posting state:

  * disable Post + Cancel
  * inputs read-only
  * show `[POSTING]`
* Success:

  * inline receipt replaces entry form
  * receipt shows reference #, timestamp, teller/session/branch, breakdown, drawer impact
  * actions: **Print Receipt** + **New <Transaction>**
  * focus New <Transaction>
* New <Transaction> resets form and focuses first field.

## 10. Error Presentation Contract

Severity model:

* **Blocking** (red, Post disabled, focus invalid field)
* **Approval Required** (neutral state + modal on post, not red)
* **Warning** (yellow, Post allowed, no focus change)
* **System Error** (red SYSTEM, Post disabled, focus Post)

Field errors:

* `aria-invalid="true"`
* `aria-describedby` to inline error text

Banner order:

1. Blocking
2. Approval notice
3. Warning

## 11. Cross-Transaction Consistency Matrix (PR Gate)

Must be identical across Deposit/Withdrawal/Transfer:

* skeleton zones
* badge vocabulary
* error severity mapping
* posting/receipt lifecycle
* keyboard + tab scope rules
* focus recovery rules
* drawer footer semantics

## 12. Versioning & Change Control

* Contract changes require:

  * version bump
  * changelog entry
  * explicit “Breaking UX change” note if tab order / shortcuts / posting lifecycle changes

(Aligns with your existing conceptual standards and contract artifacts.)

---

# 2) Developer Implementation Blueprint

**File:** `docs/teller_ui_implementation_blueprint_v1.md`
**Goal:** Make the contract enforceable through shared partials + Stimulus contracts + testable selectors.

## 1. View/Partial Structure

### Teller page templates (one per transaction)

* `app/views/teller/deposits/new.html.erb`
* `app/views/teller/withdrawals/new.html.erb`
* `app/views/teller/transfers/new.html.erb`
* etc.

### Mandatory shared partials

* `teller/shared/_topbar.html.erb` *(display-only)*
* `teller/shared/_command_bar.html.erb` *(tabindex=-1 buttons + F-key labels)*
* `teller/shared/_page_header.html.erb` *(title + state badge + hints)*
* `teller/shared/_error_banner_region.html.erb`
* `teller/shared/_reference_panel.html.erb` *(read-only KV rows)*
* `teller/shared/_totals_panel.html.erb` *(read-only totals + status)*
* `teller/shared/_drawer_footer.html.erb` *(read-only cash impact / no cash)*
* `teller/shared/_approval_modal.html.erb` *(focus trap + approve/deny)*
* `teller/shared/_receipt_block.html.erb` *(print + new transaction)*

### Optional shared form primitives

* `shared/form/_money_field.html.erb` *(right aligned tabular)*
* `shared/form/_search_field.html.erb` *(combobox pattern)*
* `shared/form/_readonly_kv.html.erb` *(reference rows)*

## 2. DOM Contract (Targets & Data Attributes)

Wrap each transaction page in one controller root:

* `data-controller="teller-tx keyboard shortcuts totals reference approval receipt"`

Common targets (names illustrative; standardize them):

* `teller-tx.postButton`
* `teller-tx.cancelButton`
* `teller-tx.form`
* `teller-tx.focusScope`
* `teller-tx.stateBadge`
* `teller-tx.errorRegion`

Line items:

* `line-items.container`
* `line-items.template`

Receipt:

* `receipt.printButton`
* `receipt.newButton`

Approval modal:

* `approval.dialog`
* `approval.supervisorId`
* `approval.password`
* `approval.reasonCode`
* `approval.approveButton`
* `approval.denyButton`

## 3. Stimulus Controller Responsibilities

### `keyboard_controller`

* Listens for F2–F4, F6–F10, Esc, Ctrl+Enter
* Never traps Tab
* Blocks mode switching while `isPosting`
* Dirty-check on mode switch → confirm dialog (native `<dialog>` preferred)

### `teller_tx_controller` (orchestrator)

* Tracks state: `editing | posting | posted`
* Dirty tracking
* Enables/disables Post based on totals + validation + approval flags
* Owns cancel confirm flow
* Coordinates focus recovery rules

### `totals_controller`

* Computes client totals for UX feedback
* Emits events: `tx:balance_changed`, `tx:totals_changed`
* Must never invent business math that diverges from server; server remains authoritative

### `reference_controller`

* Updates projected balances based on selected account + totals
* Read-only updates only

### `line_items_controller`

* Adds/removes rows
* Focuses first field on add
* Focuses neighbor on remove
* Emits `tx:recalc`

### `approval_controller`

* Owns modal lifecycle + focus trap
* Emits `tx:approval_granted` / `tx:approval_denied`
* Clears credentials on close

### `receipt_controller`

* Renders posted receipt view state
* Print calls `window.print()`
* New transaction triggers reset and focus-first-field

## 4. Event Contract (Inter-controller)

Standardize custom events:

* `tx:recalc`
* `tx:validation_errors`
* `tx:approval_required`
* `tx:approval_granted`
* `tx:approval_denied`
* `tx:posting_started`
* `tx:posted_success`
* `tx:posted_failed`

## 5. Form Submission Contract

* Ctrl+Enter triggers the same path as clicking Post
* During posting:

  * set `isPosting=true`
  * disable Post/Cancel
  * set inputs readonly
* On success:

  * render receipt block (Turbo frame or DOM swap)
  * focus New button

## 6. Accessibility/Native Controls Requirements

* No clickable divs
* Error fields use `aria-invalid` + `aria-describedby`
* Blocking banner uses `role="alert"`
* Warning uses `aria-live="polite"`
* Modal traps focus and restores focus to Post

## 7. Test Hooks (Recommended)

Add stable selectors for system tests:

* `data-testid="command-bar"`
* `data-testid="post"`
* `data-testid="cancel"`
* `data-testid="receipt-new"`
* `data-testid="approval-dialog"`

---

# 3) UI Visual Wireframe Spec

**File:** `docs/teller_ui_wireframe_spec_v1.md`
**Purpose:** Provide consistent “what it looks like” references for every screen in Traditional style.

## 1. Global Layout (All Transactions)

```text
TOP CONTEXT (display-only)
-------------------------------------------------------------------------------
COMMAND BAR (clickable, F-keys shown, not tabbable)
-------------------------------------------------------------------------------
TITLE                           [STATE]     Actions: Esc Cancel | Ctrl+Enter Post
-------------------------------------------------------------------------------
ERROR BANNER REGION (only if needed)
-------------------------------------------------------------------------------
┌──────────────────────────────────────────┬───────────────────────────────────┐
│ ENTRY FORM (only tabbable region)        │ REFERENCE PANEL(S) (read-only)     │
│                                          │                                   │
│ ...inputs...                             │ ...balances/alerts/projections... │
└──────────────────────────────────────────┴───────────────────────────────────┘
TOTALS (read-only, authoritative formatting)
-------------------------------------------------------------------------------
DRAWER FOOTER (read-only)
-------------------------------------------------------------------------------
```

## 2. Deposit (Traditional)

* Entry: Account, Cash, +Add Check, dynamic check rows, optional hold per row
* Totals: Cash, Checks, Total Deposit, Status
* Drawer: Net cash + projected drawer

## 3. Withdrawal (Traditional)

* Entry: Account, Amount, Fee, Disbursement (Cash/Draft/Mixed), conditional draft + ID
* Totals: Amount, Fee, Account Debit Total, Cash Out / Draft, Credits Total, Status / delta
* Drawer: Net cash out + projected drawer

## 4. Transfer (Traditional)

* Entry: From, To, Amount, Memo
* Totals: Debit From, Credit To, Status Balanced
* Drawer: “NO CASH MOVEMENT”

## 5. Posted Receipt Block (All Transactions)

Replaces entry form area after successful post:

```text
------------------------------------------------------
<TRANSACTION> POSTED
Ref #: <ref>
Posted: <server time>
Teller: <id>  Session: <id>  Branch: <id>
------------------------------------------------------
<breakdown lines>
------------------------------------------------------
[Print Receipt]   [New <Transaction>]
```

Focus lands on **New <Transaction>**.

## 6. Approval Modal (All Transactions)

```text
┌─────────────────────────────────────────────────────────────┐
│ APPROVAL REQUIRED                                           │
├─────────────────────────────────────────────────────────────┤
│ Reason: <reason>                                            │
│ Supervisor ID: [_________]                                  │
│ Password:      [_________]                                  │
│ Reason Code:   [_________]                                  │
│ [Deny (Esc)]                          [Approve (Enter)]     │
└─────────────────────────────────────────────────────────────┘
```

## 7. Error Presentation (All Transactions)

* Inline field errors under the field
* Banner region shows (in order): Blocking → Approval notice → Warning
* Out-of-balance: delta shown, Post disabled
