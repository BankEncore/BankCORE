---
status: considering
category: considering
updated: 2026-03-01
---

## BankCORE — Technical UI Reference Implementation Outline (Conceptual)

This outlines a clean Rails/Turbo/Stimulus approach that matches the Teller UI contract, while staying implementation-agnostic.

---

# 1\) Recommended Rails Structure

## 1.1 Routes (conceptual)

```
namespace :teller do
  root "dashboard#index"

  resources :deposits, only: [:new, :create]
  resources :withdrawals, only: [:new, :create]
  resources :transfers, only: [:new, :create]
  resources :check_cashing, only: [:new, :create]
  resources :drafts, only: [:new, :create]
  resources :bill_payments, only: [:new, :create]
  resources :misc_receipts, only: [:new, :create]
  resources :vault_transfers, only: [:new, :create]

  # UI support endpoints
  get  "accounts/search" => "accounts#search"
  get  "accounts/:id/reference" => "accounts#reference"

  post "transactions/validate" => "transactions#validate"
  post "approvals" => "approvals#create"
end
```

---

# 2\) Controllers: Responsibilities Only

## 2.1 Teller transaction controllers (e.g., DepositsController)

Responsibilities:

* Render the transaction page  
* Accept POST of transaction form payload  
* Call posting service (atomic)  
* Render receipt/success or return errors

Pattern:

* `new` → render UI shell \+ entry partial  
* `create` → validate \+ post in a DB transaction, or return errors

## 2.2 AccountsController (UI lookup)

* `search` returns list of accounts for selection (Turbo frame/JSON)  
* `reference` returns read-only account info \+ alerts \+ restrictions (Turbo frame/JSON)

## 2.3 TransactionsController (pre-post validation)

* Receives full form payload  
    
* Performs server-side validation without posting  
    
* Returns:  
    
  * blocking errors  
  * warnings  
  * approval requirement (reason codes)  
  * authoritative totals (optional but recommended)

## 2.4 ApprovalsController (supervisor interrupt)

* Validates supervisor credentials and role  
* Records approval event  
* Returns approval id/token (for inclusion in transaction create)

---

# 3\) Form Objects: Make Payload Deterministic

Use form objects per transaction type. These are not ActiveRecord models; they normalize inputs and keep validations centralized.

Example:

* `Teller::DepositForm`  
* `Teller::WithdrawalForm`  
* `Teller::TransferForm`  
* etc.

Each form object:

* Parses params into normalized structure  
    
* Validates required fields  
    
* Computes authoritative totals  
    
* Exposes:  
    
  * `errors`  
  * `warnings`  
  * `approval_required?` \+ `approval_reason_code`

---

# 4\) Service Objects: One Posting Entry Point

## 4.1 Validator service

`Teller::Transactions::Validate`

Inputs:

* transaction\_type  
* normalized form payload

Outputs:

* `ok?`  
* errors/warnings  
* approval requirement  
* authoritative totals/projections

## 4.2 Posting service (atomic)

`Teller::Transactions::Post`

Inputs:

* normalized form payload  
* teller session context  
* approval metadata (optional)

Behavior:

* start DB transaction  
* create teller transaction record  
* create posting legs  
* create cash movements  
* create instrument records  
* create audit events  
* commit or rollback

This is the boundary that must remain atomic.

---

# 5\) Views: Shared Shell \+ Transaction Partials

## 5.1 Shared partials

* topbar  
* page header  
* totals panel  
* reference panel  
* cash footer  
* approval modal  
* line item container

## 5.2 Each transaction page supplies:

* entry panel partial  
* line item template(s)

Important: The shell must be identical across pages.

---

# 6\) Turbo Frames: Where They Fit Best

## 6.1 Account search results

* Turbo frame renders dropdown/list results under search field

## 6.2 Reference panel refresh

* Turbo frame updates the read-only panel when account changes

## 6.3 Receipt rendering

* After `create`, render receipt page or Turbo-stream replace of content

Avoid Turbo for:

* keystroke-by-keystroke totals (client-side only)

---

# 7\) Stimulus: Event-Driven UI Contracts

## 7.1 Controllers and events

* `teller_tx_controller` (orchestrator)  
* `line_items_controller` (dynamic rows)  
* `totals_controller` (live math)  
* `reference_panel_controller` (projection updates)  
* `approval_modal_controller` (supervisor prompt)

Use DOM events to keep coupling low:

### Emitted events (examples)

* `tx:changed` (any input change)  
* `tx:recalc` (after totals recomputed)  
* `tx:balanced` / `tx:unbalanced`  
* `tx:approval_required`  
* `tx:approval_granted`  
* `tx:validation_errors`

---

# 8\) Suggested UI Submit Flow (Concrete Sequence)

## 8.1 Editing

* User enters inputs  
* totals update client-side  
* Post button enabled only if balanced and minimally complete

## 8.2 Validate (server)

On “Post” click:

1. UI disables Post and shows “Validating…”  
     
2. Sends form payload to `/teller/transactions/validate`  
     
3. Server returns:  
     
   * errors → show banner \+ field highlights, re-enable editing  
   * approval required → open modal, keep state  
   * ok → proceed to posting

## 8.3 Approval

If required:

1. Modal collects supervisor credentials \+ reason code  
2. POST `/teller/approvals`  
3. Returns approval id/token  
4. UI stores it in hidden field and resumes validation/post path

## 8.4 Post (atomic)

POST to the transaction `create` endpoint.

* If success: receipt  
* If fail: show errors without clearing entered data

---

# 9\) Projection Strategy (Recommended)

### Client-side projection

For simple cases:

* `projected_ledger = ledger + net_effect`  
* `projected_available = available + net_effect` (plus hold adjustments if known)

### Server-side projection

For complex cases (holds, special rules):

* call `/transactions/validate` (or `/preview`) to return authoritative projected balances

Rule:

* The server always wins; UI must accept server truth at validate/post.

---

# 10\) “Parity Guard” Between UI Math and Posting Math

Minimum requirement:

* Server recomputes totals from submitted payload and rejects mismatches.

Recommended:

* Validation response returns authoritative totals and UI displays them before final commit.  
* Posting repeats validation to ensure consistency.

This prevents UI drift from posting engine rules.

---

# 11\) Minimal First Build (Practical)

To get to a working v1 quickly:

1. Build shared teller shell \+ totals panel \+ approval modal  
2. Implement Deposit:  
   * cash \+ add check rows \+ optional hold UI  
   * server validate and post  
3. Implement Withdrawal (cash-only), then extend to mixed  
4. Implement Transfer (dual panels)  
5. Implement Non-customer check cashing

This yields maximum value with minimal rework.

---

# 12\) Deliverables You Can Track in MantisBT

* UI Shell \+ Shared Partials  
* Stimulus orchestration  
* Account search \+ reference endpoints  
* Validate endpoint \+ rule structure  
* Approval endpoint \+ audit records  
* Deposit screen end-to-end  
* Withdrawal screen end-to-end (cash-only then mixed)  
* Transfer screen end-to-end  
* Check cashing non-customer end-to-end
