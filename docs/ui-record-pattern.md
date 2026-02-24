Below is a **publish-ready document** you can drop directly into:

```
docs/ui-record-pattern.md
```

---

# BankCORE UI Record Pattern

**Version:** 1.0
**Scope:** CSR / Backoffice record screens
**Applies To:** Account, Party, Loan, Certificate, Safe Deposit, Internal Entity, etc.

---

# 1. Purpose

This document defines the **standard record screen structure** for BankCORE.

All entity “show” screens must follow this pattern to ensure:

* Predictable layout
* Operational clarity
* Workstation-style consistency
* Regulatory defensibility
* Reduced UI drift over time

This is not a marketing layout.
This is a structured operational system interface.

---

# 2. Design Principles

1. Desktop-first
2. Compact, not decorative
3. Structured hierarchy
4. Clear section boundaries
5. No visual experimentation per screen
6. Consistent spacing rhythm
7. Financial data uses tabular numerics
8. Status always visible

---

# 3. Record Screen Structure

Every record screen follows this order:

```
[A] Record Header
[B] Summary Strip (optional, entity-dependent)
[C] Core Details Panel
[D] Relationship Panel(s)
[E] Financial / Activity Panel(s)
[F] Secondary Panels (Notes, Flags, Audit, etc.)
```

Not all sections are required, but ordering must remain consistent.

---

# 4. Section Definitions

---

## A. Record Header (Mandatory)

### Purpose

* Identify record
* Display classification
* Display status
* Present primary actions

### Layout Pattern

```
Title + Status Badge                   Actions
Subtitle
----------------------------------------------
```

### Title Rules

* `text-lg`
* `font-semibold`
* No oversized hero text
* Record identifier included if appropriate

Examples:

**Account**

```
Account 000123456   [Active]
Checking • Main Branch
```

**Party**

```
Thomas Miller   [Active]
Individual • Customer
```

---

### Header Partial Template

```erb
<section class="mb-4">
  <div class="flex items-start justify-between gap-6">
    <div>
      <div class="flex items-center gap-3">
        <h1 class="text-lg font-semibold tracking-tight">
          <%= title %>
        </h1>

        <% if status.present? %>
          <span class="badge badge-outline">
            <%= status %>
          </span>
        <% end %>
      </div>

      <% if subtitle.present? %>
        <div class="mt-1 text-sm text-base-content/60">
          <%= subtitle %>
        </div>
      <% end %>
    </div>

    <div class="flex items-center gap-2">
      <%= yield :header_actions %>
    </div>
  </div>

  <div class="mt-3 border-b border-base-300"></div>
</section>
```

---

## B. Summary Strip (Recommended for Financial Records)

Used for:

* Account
* Loan
* Certificate
* Any balance-driven entity

Purpose:

* Display operationally critical values immediately

### Pattern

```erb
<div class="card bg-base-100 border border-base-300 mb-4">
  <div class="card-body py-3">
    <div class="grid grid-cols-2 md:grid-cols-4 gap-4 text-sm">
      <div>
        <div class="text-base-content/60">Ledger</div>
        <div class="font-semibold tabular-nums">$4,250.00</div>
      </div>
    </div>
  </div>
</div>
```

### Rules

* No colored backgrounds
* No marketing-style emphasis
* Use `tabular-nums` for all monetary values

---

## C. Core Details Panel (Mandatory)

Used for:

* Metadata
* Classification
* Open/close dates
* Structural attributes

### Rules

* Use divided rows
* Left = label (muted)
* Right = value
* No form-style grid layouts
* `text-sm` for body
* Tabular numbers for numeric/date fields

### Standard Pattern

```erb
<section class="card bg-base-100 border border-base-300 mb-4">
  <div class="card-body">
    <h2 class="card-title text-base">Details</h2>

    <dl class="mt-3 divide-y divide-base-300/60 text-sm">
      <div class="flex justify-between py-2">
        <dt class="text-base-content/70">Field</dt>
        <dd>Value</dd>
      </div>
    </dl>
  </div>
</section>
```

---

## D. Relationship Panels

Used for:

* Account → Owners
* Party → Accounts
* Loan → Borrowers
* Party → Related Parties

### Pattern

* Card wrapper
* Compact table
* `table table-sm`
* Hover rows
* Badge for primary or role
* Row count in top right (optional)

### Visual Rules

* No excessive whitespace
* Avoid form controls unless editing
* Keep operational density high but readable

---

## E. Financial / Activity Panels

Used for:

* Transaction history
* Payment history
* Posting history
* Balance ledger
* Hold activity

### Preferred Approach

Stacked panels rather than tabs.

Reason:

* More workstation-style
* Less “web app” feel
* Easier for auditors to scroll and review

Tabs are acceptable only if:

* 3+ clearly separate content modes
* Density becomes excessive

---

## F. Secondary Panels

Examples:

* Notes
* Flags
* Compliance holds
* Documents
* Audit trail

Rules:

* Same card styling
* Same vertical rhythm
* No unique styling per section

---

# 5. Visual Rhythm Standards

All record pages must adhere to:

| Element          | Standard                                  |
| ---------------- | ----------------------------------------- |
| Card wrapper     | `card bg-base-100 border border-base-300` |
| Vertical spacing | `mb-4`                                    |
| Section title    | `card-title text-base`                    |
| Body text        | `text-sm`                                 |
| Monetary values  | `tabular-nums`                            |
| Status badges    | `badge badge-outline`                     |
| Dividers         | `divide-base-300/60`                      |
| Borders          | No heavy contrast                         |

---

# 6. Typography Rules

* No oversized display headings
* Avoid decorative fonts
* `tabular-nums` for:

  * Money
  * Dates
  * Account numbers
* Monospace only for identifiers when appropriate
* Do not overuse bold

---

# 7. Behavioral Standards

## Status Visibility

Status must be visible in the header at all times.

## Action Placement

Primary actions:

* Top-right in header
* `btn btn-sm`
* Primary action uses `btn-primary`
* Secondary actions use `btn-ghost`
* Destructive actions use `btn-error`

## No Inline Edit Forms on Record Pages

Editing should redirect to:

* Dedicated edit screen
* Modal (only when clearly bounded)

---

# 8. What This Pattern Prevents

* Marketing-style hero layouts
* Random grid layouts per screen
* Inconsistent spacing
* Overly modern SaaS visual patterns
* Screen-to-screen drift
* Visual clutter

---

# 9. Example: Account Record Structure

```erb
<%= render "csr/shared/page_header", ... %>

<%= render "csr/accounts/summary_strip", account: @account %>

<%= render "csr/accounts/details", account: @account %>

<%= render "csr/accounts/owners", account: @account %>

<%= render "csr/accounts/activity", account: @account %>

<%= render "csr/shared/notes_panel", record: @account %>
```

---

# 10. Governance Rule

Any new entity screen must:

* Follow this structure
* Use standard card styling
* Maintain section order
* Avoid introducing new visual patterns without updating this document

Changes to this pattern require:

* Document update
* Version increment
* Explicit approval in UI review

---

# 11. Version History

**1.0**

* Initial formalization of BankCORE Record Screen Pattern
* Established section order and visual rhythm standards

---

If you’d like next, I can:

* Draft a companion `docs/ui-edit-pattern.md`
* Or create a small CSR layout wrapper so all record screens inherit spacing and section rhythm automatically
