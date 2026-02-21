## BankCORE Teller UI/UX Standards

### 1\) Global interaction rules

* **Transaction-first UX:** Each page represents a single teller transaction in progress.  
* **No mid-transaction reloads:** Editing state must persist until the teller cancels or posts.  
* **Non-destructive interrupts:** Validation failures and supervisor approvals must never clear the form.  
* **Progressive disclosure:** Only show fields needed for the selected transaction type and current state.  
* **Dynamic line entry:** Repeating inputs use `+ Add …` (checks, splits, IDs). No fixed blank grids.  
* **Real-time feedback:** Totals/subtotals, out-of-balance indicators, projected balances, and threshold warnings update live.  
* **Separation of input vs reference:** Editable fields live in the entry column; reference data is read-only and visually distinct.

### 2\) Required screen zones (consistent on every teller transaction page)

1. **Top Context Bar (persistent):** teller \+ session \+ branch \+ time  
2. **Page Header:** transaction type \+ state badges \+ primary action  
3. **Entry Panel (left):** required inputs only  
4. **Reference Panel (right):** account/party details, alerts, restrictions, projected balances  
5. **Live Totals Panel:** subtotals \+ balance indicator \+ “out of balance” delta  
6. **Cash Impact Footer (persistent):** net cash movement \+ projected drawer balance

### 3\) Status language and visual semantics

* **Balanced** (success) → posting allowed  
* **Out of Balance** (error) → posting disabled, show delta  
* **Approval Required** (warning) → posting disabled until approved  
* **Blocked** (error) → posting prohibited (e.g., frozen account, OFAC match)

### 4\) Supervisor approval standard

* Triggered from validation or real-time thresholds.  
* Presented as **modal or inline panel**.  
* Approve/deny does not discard data.  
* Approval metadata is attached to the transaction.

---

# Conceptual Page Examples (Rails \+ Tailwind \+ DaisyUI)

The snippets below illustrate consistent use of DaisyUI primitives (`navbar`, `card`, `alert`, `badge`, `stats`, `collapse`, `btn`) and the interaction model.

All examples are intentionally “UI-only”: they show layout and behavior expectations, not full controller wiring.

---

## A) Shared Teller Page Shell

```
<div class="navbar bg-base-200 border-b border-base-300">
  <div class="flex-1">
    <span class="text-lg font-semibold">BankCORE</span>
    <span class="ml-3 text-sm opacity-70">Teller</span>
  </div>

  <div class="flex items-center gap-2 text-sm">
    <span class="badge badge-outline">Teller: T001</span>
    <span class="badge badge-outline">Session: S045</span>
    <span class="badge badge-outline">Branch: 001</span>
    <span class="opacity-70">03/18/2026 11:08 AM</span>
  </div>
</div>

<div class="p-4 space-y-4">
  <div class="flex items-start justify-between gap-3">
    <div>
      <h1 class="text-2xl font-semibold">Deposit</h1>
      <div class="mt-2 flex flex-wrap gap-2">
        <span class="badge badge-success">Balanced</span>
        <%# <span class="badge badge-warning">Approval Required</span> %>
        <%# <span class="badge badge-error">Out of Balance</span> %>
      </div>
    </div>

    <div class="flex gap-2">
      <button class="btn btn-ghost">Cancel</button>
      <button class="btn btn-primary" disabled>Post</button>
    </div>
  </div>

  <div class="grid grid-cols-1 lg:grid-cols-3 gap-4">
    <section class="lg:col-span-2 space-y-4">
      <%# Entry + line items go here %>
      <%# Live totals panel goes here %>
    </section>

    <aside class="space-y-4">
      <%# Reference panel %>
      <%# Cash impact footer %>
    </aside>
  </div>

  <%# Supervisor approval modal sits at the end of the page %>
</div>
```

---

## B) Deposit Page (Add Check \+ Optional Hold)

### Entry Panel

```
<div class="card bg-base-100 border border-base-300">
  <div class="card-body">
    <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
      <label class="form-control">
        <div class="label"><span class="label-text">Account</span></div>
        <input class="input input-bordered" placeholder="Search name / account #">
      </label>

      <label class="form-control">
        <div class="label"><span class="label-text">Cash Amount</span></div>
        <input class="input input-bordered text-right tabular-nums" inputmode="decimal" placeholder="0.00">
      </label>
    </div>

    <div class="divider my-3"></div>

    <div class="flex items-center justify-between">
      <div class="font-medium">Checks</div>
      <button class="btn btn-sm btn-outline">+ Add Check</button>
    </div>

    <div class="mt-3 space-y-3">
      <%# check rows inserted here dynamically %>
    </div>
  </div>
</div>
```

### Check Row (dynamic) \+ Optional Hold

```
<div class="card bg-base-100 border border-base-300">
  <div class="card-body p-4">
    <div class="grid grid-cols-1 md:grid-cols-4 gap-3">
      <input class="input input-bordered" placeholder="Routing #" inputmode="numeric">
      <input class="input input-bordered" placeholder="Account #" inputmode="numeric">
      <input class="input input-bordered" placeholder="Check #" inputmode="numeric">
      <input class="input input-bordered text-right tabular-nums" placeholder="Amount" inputmode="decimal">
    </div>

    <div class="mt-3 collapse collapse-arrow bg-base-200">
      <input type="checkbox">
      <div class="collapse-title text-sm font-medium">Optional: Hold</div>
      <div class="collapse-content">
        <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
          <select class="select select-bordered">
            <option value="">Hold reason (none)</option>
            <option>New Account</option>
            <option>Large Item</option>
            <option>Exception</option>
          </select>
          <input class="input input-bordered" type="date">
        </div>
      </div>
    </div>

    <div class="mt-3 flex justify-end">
      <button class="btn btn-ghost btn-sm">Remove</button>
    </div>
  </div>
</div>
```

---

## C) Live Totals Panel (Real-Time \+ Out-of-Balance)

```
<div class="card bg-base-100 border border-base-300">
  <div class="card-body">
    <div class="flex items-center justify-between">
      <div class="text-lg font-semibold">Transaction Summary</div>
      <span class="badge badge-success">Balanced</span>
    </div>

    <div class="mt-3 grid grid-cols-2 gap-3 text-sm">
      <div class="opacity-70">Cash</div>
      <div class="text-right tabular-nums">$500.00</div>

      <div class="opacity-70">Checks</div>
      <div class="text-right tabular-nums">$250.00</div>

      <div class="col-span-2"><div class="divider my-1"></div></div>

      <div class="font-semibold">Total</div>
      <div class="text-right tabular-nums font-semibold">$750.00</div>
    </div>

    <%# Shown only when needed %>
    <div class="mt-3 alert alert-error hidden">
      <span class="font-semibold">Out of Balance:</span>
      <span class="tabular-nums ml-2">$125.00</span>
    </div>
  </div>
</div>
```

---

## D) Reference Panel (Read-Only \+ Projected Balances)

```
<div class="card bg-base-200 border border-base-300">
  <div class="card-body">
    <div class="font-semibold">Account Reference</div>

    <div class="mt-3 text-sm space-y-2">
      <div class="flex justify-between">
        <span class="opacity-70">Account</span><span>Checking ****1234</span>
      </div>
      <div class="flex justify-between">
        <span class="opacity-70">Status</span><span>Active</span>
      </div>

      <div class="divider my-1"></div>

      <div class="flex justify-between">
        <span class="opacity-70">Ledger</span><span class="tabular-nums">$4,250.00</span>
      </div>
      <div class="flex justify-between">
        <span class="opacity-70">Available</span><span class="tabular-nums">$4,100.00</span>
      </div>

      <div class="divider my-1"></div>

      <div class="flex justify-between">
        <span class="opacity-70">Projected Ledger</span><span class="tabular-nums">$4,750.00</span>
      </div>
      <div class="flex justify-between">
        <span class="opacity-70">Projected Available</span><span class="tabular-nums">$4,600.00</span>
      </div>
    </div>

    <div class="mt-4">
      <div class="font-medium">Alerts</div>
      <div class="mt-2 space-y-2">
        <div class="alert alert-warning text-sm">Large cash monitoring applies.</div>
      </div>
    </div>
  </div>
</div>
```

---

## E) Cash Impact Footer (Persistent)

```
<div class="card bg-base-100 border border-base-300">
  <div class="card-body">
    <div class="font-semibold">Drawer Impact</div>
    <div class="mt-2 text-sm space-y-2">
      <div class="flex justify-between">
        <span class="opacity-70">Net Cash Movement</span>
        <span class="tabular-nums">+$500.00</span>
      </div>
      <div class="flex justify-between">
        <span class="opacity-70">Projected Drawer</span>
        <span class="tabular-nums">$12,930.00</span>
      </div>
    </div>
  </div>
</div>
```

---

## F) Supervisor Approval Modal (Non-Destructive Interrupt)

```
<dialog id="supervisor_modal" class="modal">
  <div class="modal-box">
    <h3 class="font-semibold text-lg">Supervisor Approval Required</h3>
    <p class="text-sm opacity-70 mt-1">Reason: Threshold exceeded</p>

    <div class="mt-4 grid grid-cols-1 gap-3">
      <input class="input input-bordered" placeholder="Supervisor ID">
      <input class="input input-bordered" placeholder="Password" type="password">
      <select class="select select-bordered">
        <option value="">Select approval reason…</option>
        <option value="threshold">Threshold exceeded</option>
        <option value="nsf">Insufficient funds override</option>
        <option value="restricted">Restricted account override</option>
      </select>
    </div>

    <div class="modal-action flex gap-2">
      <form method="dialog">
        <button class="btn btn-ghost">Deny</button>
      </form>
      <button class="btn btn-primary">Approve & Continue</button>
    </div>
  </div>
</dialog>
```

---

# Suggested “Standards Checklist” to include in docs

- [ ] Uses consistent zones (topbar/header/entry/reference/totals/footer)  
- [ ] Progressive disclosure; no irrelevant fields  
- [ ] Add/remove line items; no fixed grids  
- [ ] Live totals and out-of-balance indicators  
- [ ] Projected balances update in real time  
- [ ] Post disabled when out-of-balance or approval pending  
- [ ] Supervisor prompt is non-destructive  
- [ ] Errors/warnings/approval states are visually distinct

---
