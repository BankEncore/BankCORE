# Tellers
* Add last_name, first_name, teller_id, and PIN hash
* Wire teller_id/pin for station unlock and supervisor authorization

# Workstation
* Branch and workstation assignment stored in cookie
* Persists across teller sessions/drawers

Below is a **visual ASCII mockup of the full BankCORE application chrome**, reflecting the Traditional / Workstation-first feel we agreed on.

This includes:

* Global app layer
* Teller shell
* Ops shell
* CIF (future) separation
* Lock state
* Approval modal state

---

# 1️⃣ Global Application Chrome (Authenticated)

```text
┌──────────────────────────────────────────────────────────────────────────────┐
│ BANKCORE                                      User: TSM  | Role: Teller     │
│ Branch: 001 – Main St                          03/18/2026  10:42 AM  | Logout│
└──────────────────────────────────────────────────────────────────────────────┘
```

Thin, muted, operational.
No branding theatrics. No gradients.

---

# 2️⃣ Teller Shell Chrome (`/teller/*`)

## A. Normal Transaction State

```text
┌──────────────────────────────────────────────────────────────────────────────┐
│ BANKCORE | Teller: T001 | Session: S045 | Branch: 001 | 10:42 AM           │
├──────────────────────────────────────────────────────────────────────────────┤
│ [Dashboard] [Deposit] [Withdrawal] [Transfer] [Check Cashing] [Draft]      │
│ [Bill Payment] [Misc Receipt] [Vault Transfer]                              │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  DEPOSIT                                                                     │
│  ─────────────────────────────────────────────────────────────────────────   │
│                                                                              │
│  ┌──────────────────────────────┐   ┌────────────────────────────────────┐   │
│  │ TRANSACTION ENTRY            │   │ ACCOUNT REFERENCE (Read-Only)      │   │
│  │                              │   │                                    │   │
│  │ Account: [ Search Field ]    │   │ Thomas Miller                      │   │
│  │ Cash Amount: [     500.00 ]  │   │ Account #: ****1234                │   │
│  │ Check Amount: [     200.00 ] │   │ Status: Active                     │   │
│  │ Memo: [____________________] │   │ Ledger Balance:   $4,250.00        │   │
│  │                              │   │ Available:        $4,100.00        │   │
│  │ [Cancel]        [Post]       │   │                                    │   │
│  └──────────────────────────────┘   └────────────────────────────────────┘   │
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────────────┐   │
│  │ TOTALS                                                                │   │
│  │   Cash In:         $500.00                                            │   │
│  │   Checks In:       $200.00                                            │   │
│  │   Net Deposit:     $700.00                                            │   │
│  │   Status: BALANCED                                                    │   │
│  └────────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
├──────────────────────────────────────────────────────────────────────────────┤
│ Drawer Before: $3,200.00  |  + Cash In: $500.00  |  Drawer After: $3,700.00│
└──────────────────────────────────────────────────────────────────────────────┘
```

Key characteristics:

* Strong structural borders
* Two-column operational layout
* Totals always visible
* Drawer impact always visible
* No cards
* No floating UI

---

## B. Approval Required State

```text
┌──────────────────────────────────────────────────────────────────────────────┐
│  [APPROVAL REQUIRED]                                                         │
│  Withdrawal exceeds $5,000 limit. Supervisor authorization required.        │
└──────────────────────────────────────────────────────────────────────────────┘
```

Then modal:

```text
              ┌────────────────────────────────────────────┐
              │ SUPERVISOR APPROVAL REQUIRED               │
              │                                            │
              │ Supervisor ID: [__________]                │
              │ Password:      [__________]                │
              │                                            │
              │ [Cancel]                 [Approve]         │
              └────────────────────────────────────────────┘
```

* Background interaction disabled
* No animation
* Procedural tone

---

## C. Receipt State (Post-Success)

```text
┌──────────────────────────────────────────────────────────────────────────────┐
│  RECEIPT                                                                     │
│  Ref #: 20260318-000145                                                       │
│  Timestamp: 03/18/2026 10:44 AM                                               │
│                                                                              │
│  Deposit                                                                      │
│    Cash:           $500.00                                                   │
│    Checks:         $200.00                                                   │
│    Net:            $700.00                                                   │
│                                                                              │
│  Drawer Before:    $3,200.00                                                 │
│  Drawer After:     $3,700.00                                                 │
│                                                                              │
│  [Print Receipt]   [New Transaction]   [Return to Dashboard]                │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

# 3️⃣ Workstation Locked State

```text
┌──────────────────────────────────────────────────────────────────────────────┐
│  WORKSTATION LOCKED                                                          │
│                                                                              │
│  This workstation is locked.                                                 │
│                                                                              │
│  User ID: TSM                                                                │
│  Password: [__________]                                                      │
│                                                                              │
│                 [Unlock]                                                     │
└──────────────────────────────────────────────────────────────────────────────┘
```

No navigation visible.
No transaction elements accessible.

---

# 4️⃣ Session Status (No Open Session)

```text
┌──────────────────────────────────────────────────────────────────────────────┐
│  SESSION STATUS                                                              │
│                                                                              │
│  No open teller session for this workstation.                                │
│                                                                              │
│               [Open Session]                                                 │
└──────────────────────────────────────────────────────────────────────────────┘
```

Minimal. Clear gate.

---

# 5️⃣ Ops Shell Chrome (`/ops/*`)

Different feel — more reporting-oriented.

```text
┌──────────────────────────────────────────────────────────────────────────────┐
│ BANKCORE OPS | User: Supervisor | Branch Scope: All | 10:42 AM | Logout    │
├──────────────────────────────────────────────────────────────────────────────┤
│ [Teller Activity] [Session Search]                                           │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  FILTERS                                                                     │
│  Branch: [All ▼]  Date: [03/18/2026]  Teller: [All ▼]  [Run Report]        │
│                                                                              │
│  ─────────────────────────────────────────────────────────────────────────   │
│                                                                              │
│  Teller Activity Report                                                      │
│                                                                              │
│  Teller   Sessions  Cash In   Cash Out   Fees   Reversals   Net Cash       │
│  T001     1         12,000    8,500      320    1           +3,500         │
│  T002     1         8,200     9,000      210    0           -800           │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

Differences from Teller:

* No drawer footer
* No transaction buttons
* More scrolling
* More filters
* Data tables primary

---

# 6️⃣ CIF (Future — Separate Tab)

When teller clicks account:

New browser tab:

```text
┌──────────────────────────────────────────────────────────────────────────────┐
│ BANKCORE CIF | Party: Thomas Miller | Account: 1234 | Logout               │
├──────────────────────────────────────────────────────────────────────────────┤
│ [Profile] [Accounts] [Documents]                                             │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│ Account Summary                                                              │
│                                                                              │
│ Ledger Balance: $4,250.00                                                    │
│ Available:      $4,100.00                                                    │
│ Holds:          $150.00                                                      │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

Critically:

* Does NOT disrupt teller session
* Does NOT embed inside transaction

---

# 7️⃣ The Feel (Condensed Summary)

The chrome communicates:

* Institutional
* Structured
* Accountable
* Deliberate
* Controlled

It avoids:

* Cards
* Rounded playful UI
* Dashboards with widgets
* Animation
* Excess whitespace
* Modern SaaS aesthetic

It feels closer to:

> Core banking workstation terminal
> Modernized, but serious.

---

If you'd like, next I can:

* Convert this into a **CSS/HTML structural scaffold**
* Or provide a **Tailwind/DaisyUI layout mapping**
* Or show where your current layout likely diverges from this model**
