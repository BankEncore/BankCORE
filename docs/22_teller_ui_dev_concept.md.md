## BankCORE Teller UI Contract (Iteration 1\)

**Status:** **CONCEPTUAL** (no canonical repo snapshot provided). **Goal:** Make UI/UX behavior enforceable via a standard page skeleton \+ shared partials \+ Stimulus contracts.

---

# 1\) File and Component Inventory

## Rails views (page templates)

```
app/views/teller/
  dashboard/index.html.erb

  deposits/new.html.erb
  withdrawals/new.html.erb
  transfers/new.html.erb
  check_cashing/new.html.erb
  drafts/new.html.erb
  bill_payments/new.html.erb
  misc_receipts/new.html.erb
  vault_transfers/new.html.erb
```

## Shared partials (must exist; reused across all teller pages)

```
app/views/teller/shared/
  _topbar.html.erb              # teller/session/branch + clock
  _page_header.html.erb         # title + status badges + primary actions
  _reference_panel.html.erb     # account/party read-only panel
  _totals_panel.html.erb        # live totals + balance indicator + projected balances
  _cash_footer.html.erb         # drawer impact preview (net cash movement, projected drawer)
  _alerts_list.html.erb         # alerts + restrictions rendering
  _approval_modal.html.erb      # supervisor interrupt prompt
  _line_item_container.html.erb # consistent “Add item” section wrapper
  _errors_banner.html.erb       # blocking errors summary (non-destructive)
```

## Shared UI primitives (optional but recommended)

```
app/views/shared/form/
  _money_field.html.erb         # right-aligned numeric, tabular-nums, inputmode=decimal
  _search_field.html.erb        # search/select control pattern
  _readonly_kv.html.erb         # key/value rows in reference panels
```

---

# 2\) Page Template Contract (Required Layout \+ Zones)

Every teller transaction page **must** follow this structure (same DOM zones, same semantics):

### Required Zones

1. **Topbar (persistent)** – session context  
2. **Page Header** – transaction name \+ state badges \+ actions  
3. **Main Grid** – left entry \+ right reference panel  
4. **Line Items Area** – dynamic rows (checks, splits, etc.)  
5. **Totals Panel (persistent within page)** – live calculations \+ out-of-balance indicator  
6. **Cash Footer (persistent within page)** – net cash movement \+ projected drawer

### Canonical skeleton

```
<%= render "teller/shared/topbar" %>

<div class="p-4 space-y-4" data-controller="teller-tx"
     data-teller-tx-transaction-type-value="deposit"
     data-teller-tx-mode-value="new">

  <%= render "teller/shared/page_header",
        title: "Deposit",
        primary_action_label: "Post Deposit" %>

  <div class="grid grid-cols-1 lg:grid-cols-3 gap-4">
    <section class="lg:col-span-2 space-y-4">
      <%# Entry card(s) %>
      <%= yield :entry %>

      <%# Dynamic line items section %>
      <%= yield :line_items %>

      <%# Totals (live) %>
      <%= render "teller/shared/totals_panel" %>
    </section>

    <aside class="space-y-4">
      <%= render "teller/shared/reference_panel" %>
      <%= render "teller/shared/cash_footer" %>
    </aside>
  </div>

  <%= render "teller/shared/approval_modal" %>
</div>
```

---

# 3\) UI Behavior Standards (Enforceable Rules)

## 3.1 Field visibility (context-aware \+ progressive disclosure)

* Only show inputs relevant to `transaction_type` and current state.  
* Optional sections must use `collapse` (DaisyUI) and stay hidden until expanded.  
* Never pre-render arbitrary blank rows for repeatable items.

## 3.2 Dynamic line entry

* Repeating inputs (checks, split disbursements, multiple instruments) must use:  
    
  * **“+ Add …”** button  
  * **template injection** (HTML `<template>` or server-rendered partial clone)  
  * **remove** per item


* Unlimited items; no fixed limits in UI.

## 3.3 Real-time feedback

* Totals, subtotals, projected balances, out-of-balance indicators update:  
    
  * on input change  
  * on add/remove line item  
  * without page reload


* “Post/Complete” is disabled when:  
    
  * out of balance  
  * blocking validation errors exist  
  * required approval not completed

## 3.4 Supervisor approvals are non-destructive

* Approval prompt is a modal/inline interrupt.  
    
* Transaction state must remain intact after:  
    
  * approval required  
  * approval denied  
  * validation errors


* Deny → return to editing; do not clear.

## 3.5 Error model

* Distinguish:  
    
  * **Errors** (blocking) → `alert-error`  
  * **Warnings** (non-blocking) → `alert-warning`  
  * **Approval Required** → `badge-warning` \+ modal


* Never clear the form on errors.

---

# 4\) DaisyUI/Tailwind Component Standards

## Cards and panels

* Entry: `card bg-base-100 border border-base-300`  
* Reference: `card bg-base-200 border border-base-300`  
* Summaries: `card bg-base-100 border border-base-300`

## Badges (state)

* Balanced: `badge badge-success`  
* Approval required: `badge badge-warning`  
* Out of balance / blocked: `badge badge-error`  
* Info: `badge badge-outline`

## Alerts

* Blocking: `alert alert-error`  
* Warning: `alert alert-warning`  
* Informational: `alert alert-info`

## Money fields

* `input input-bordered text-right tabular-nums`  
* `inputmode="decimal"` (or `"numeric"` where appropriate)

---

# 5\) Stimulus Controller Contracts

These are “must behave this way” contracts. Names are suggestions; the interface is the important part.

## 5.1 `teller_tx_controller` (orchestrator)

**Responsibility:** page-level state, enabling/disabling post, coordinating totals \+ approvals.

### Values

* `transactionTypeValue` (deposit/withdrawal/transfer/etc.)  
* `modeValue` (new/edit)

### Targets

* `postButton`  
* `statusBadges` (balanced/approval/outOfBalance)  
* `errorsBanner` (optional)

### Events it listens to (dispatched by other controllers)

* `tx:recalc` → recalculate/refresh view state  
* `tx:balance_changed` → toggle “Balanced/Out of balance”  
* `tx:approval_required` → open modal  
* `tx:approval_granted` → allow posting  
* `tx:approval_denied` → return to edit with warning  
* `tx:validation_errors` → show blocking errors banner

### Required behaviors

* Never resets form state.  
    
* Post button disabled unless:  
    
  * balanced  
  * valid  
  * approvals satisfied

---

## 5.2 `line_items_controller` (dynamic rows)

**Responsibility:** add/remove rows (checks, splits), emit events.

### Targets

* `container`  
* `template` (or template id reference)

### Actions

* `add()` – append a new row  
* `remove(event)` – remove row  
* `changed()` – on any input change

### Emits

* `tx:recalc` whenever add/remove/change occurs.

### UX rules

* New row focuses first field.  
* Remove prompts only if row has data (optional).

---

## 5.3 `totals_controller` (live math \+ balance status)

**Responsibility:** compute UI totals and out-of-balance; show net cash movement.

### Targets (example)

* `cashSubtotal`  
* `checkSubtotal`  
* `feeSubtotal`  
* `total`  
* `netCash`  
* `outOfBalanceBanner`  
* `outOfBalanceAmount`  
* `projectedLedger`  
* `projectedAvailable`

### Inputs it reads

* Cash amount field(s)  
* Line item amounts  
* Fee fields  
* Disbursement splits (withdrawal mixed)

### Emits

* `tx:balance_changed` (balanced boolean \+ out\_of\_balance\_amount)  
* `tx:recalc` (optional chaining)

### Rules

* Totals must match the posting engine rules (no hidden UI-only math).  
    
* When imbalance exists:  
    
  * show banner  
  * disable post (via `teller_tx_controller`)

---

## 5.4 `reference_panel_controller` (read-only account/party context)

**Responsibility:** display context when account/party selected and compute projections.

### Targets

* `title`, `status`, `ledger`, `available`, `alerts`  
* `projectedLedger`, `projectedAvailable`

### Inputs

* Selected account id (from search/select)  
* Current totals (from totals controller events)

### Required behavior

* Read-only display only; never writes transaction inputs.  
* Updates projections on `tx:recalc`.

---

## 5.5 `approval_modal_controller` (non-destructive interrupt)

**Responsibility:** handle supervisor approval modal lifecycle.

### Targets

* `reason`  
* `supervisorId`  
* `password`  
* `reasonCode`  
* `approveButton`  
* `denyButton`

### Required behavior

* Opening modal must not lose state.  
* Approve emits `tx:approval_granted` with approval metadata.  
* Deny emits `tx:approval_denied` and closes modal.  
* Credentials cleared after modal close (recommended).

---

# 6\) Page-Specific Examples (What pages look like)

## 6.1 Deposit (checks \+ holds)

**Entry area must include:**

* Account search/select  
* Cash amount  
* “+ Add Check”  
* Each check row: routing/account/check\#/amount  
* Optional “Hold” collapse inside each check row

**Right reference panel:**

* balances \+ restrictions \+ alerts \+ projections

**Totals panel:**

* cash subtotal, checks subtotal, total deposit  
* availability breakdown if holds present (optional v1)

---

## 6.2 Withdrawal (mixed disbursement)

**Entry area must include:**

* Account select  
* Withdrawal amount  
* Disbursement method radio: Cash / Draft / Mixed  
* If Mixed: split fields appear  
* Draft details appear only if draft portion \> 0  
* Fee optional (and must be included in account debit if funded from account)

**Totals panel must show:**

* Account debit total  
* Cash out  
* Draft liability created  
* Fee income (if applicable)  
* Out-of-balance indicator

**Cash footer must reflect cash portion only.**

---

## 6.3 Transfer (dual reference panels)

**Main grid changes:**

* Two reference panels (From/To), both read-only  
* Amount field centralized  
* Totals show: From debit / To credit / net cash movement \= 0

---

# 7\) Acceptance Checklist (use in PR reviews)

## Layout \+ consistency

- [ ] Uses shared topbar \+ page\_header \+ totals\_panel \+ cash\_footer  
- [ ] Reference panel is read-only and visually distinct  
- [ ] No page reload during active entry

## Progressive disclosure

- [ ] Only relevant fields appear for transaction type/state  
- [ ] Optional fields are inside collapses  
- [ ] No fixed blank grids for line items

## Line item behavior

- [ ] “+ Add …” adds one row  
- [ ] Unlimited rows supported  
- [ ] Remove works and updates totals immediately

## Real-time math

- [ ] Totals update on every change (input/add/remove)  
- [ ] Out-of-balance indicator appears instantly  
- [ ] Post button disables when out of balance

## Approvals

- [ ] Approval required is indicated before posting attempt (where possible)  
- [ ] Approval modal does not clear transaction state  
- [ ] Deny returns to editing with data preserved  
- [ ] Approvals are logged (UI passes metadata back)

## Errors

- [ ] Blocking errors prevent post and are clearly displayed  
- [ ] Warnings do not block but remain visible  
- [ ] No destructive resets on validation failures

---

