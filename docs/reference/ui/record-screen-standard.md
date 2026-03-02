# BankCORE Record Screen Standard

(Visual Reference Mock Layout)

Purpose: Provide a structural blueprint for all record-oriented screens:

- Account  
- Party  
- Loan  
- Teller Transaction  
- Batch  
- Posting  
- Any primary entity view

This enforces:

- Layout hierarchy  
- Spacing rhythm  
- Action placement  
- Panel structure  
- Density discipline

All new record screens must follow this template.

---

# 1\) Canonical Record Screen Layout

┌────────────────────────────────────────────────────────────┐ │ Header                                                    │ │ Title                                                     │ │ Context / Breadcrumb                                      │ │                                               \[Actions\]   │ └────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────┐ │ Alert Region (if applicable)                              │ └────────────────────────────────────────────────────────────┘

┌──────────────────────────────┬─────────────────────────────┐ │ Primary Panel (2/3 width)   │ Reference Panel (1/3)       │ │                              │                             │ │ ┌──────────────────────────┐ │ ┌─────────────────────────┐ │ │ │ Card: Details            │ │ │ Card: Summary           │ │ │ └──────────────────────────┘ │ └─────────────────────────┘ │ │                              │                             │ │ ┌──────────────────────────┐ │ ┌─────────────────────────┐ │ │ │ Card: Activity Table     │ │ │ Card: Flags / Limits    │ │ │ └──────────────────────────┘ │ └─────────────────────────┘ │ └──────────────────────────────┴─────────────────────────────┘

---

# 2\) Header Standard

## 2.1 Left Side

- Record title (H1)  
- Context subtitle (branch, type, status)  
- Optional breadcrumb

Example:

Account 104233  
Checking • Branch 001 • Active

## 2.2 Right Side

Maximum:

- 1 Primary action  
- 1 Secondary action  
- Overflow menu

Never:

- More than one primary  
- Destructive actions inline with primary

---

# 3\) Alert Region

Used only when necessary.

Examples:

- Out of Balance  
- Pending Approval  
- Restricted Account  
- Compliance Hold

Placement:

- Immediately below header  
- Full width  
- Consolidated (not scattered)

---

# 4\) Primary Panel (Main Column)

Occupies:

- 2/3 width desktop  
- Full width mobile

Contains:

## 4.1 Details Card

Structured key-value grid.

Example:

Account Number: 104233  
Posting Ref: DDA-104233  
Opened: 01/15/2025  
Officer: J. Smith

Rules:

- Grid layout  
- No decorative styling  
- Tight vertical rhythm

---

## 4.2 Activity Table Card

Used for:

- Ledger  
- Transaction history  
- Posting legs  
- Audit trail

Must:

- Use table  
- Right-align currency  
- Row actions in last column only  
- Compact density

Never:

- Replace with card list  
- Wrap each row in card

---

# 5\) Reference Panel (Right Column)

Occupies:

- 1/3 width desktop  
- Below primary on mobile

Used for:

- Balances  
- Limits  
- Status flags  
- Risk markers  
- Quick reference data

Lower visual weight than primary panel.

---

## 5.1 Balance Box Standard

Ledger Balance  
Available Balance  
Holds

Presented in:

- Neutral bordered box  
- Tabular numerals  
- No bright colors

Do not use:

- Large marketing cards  
- Decorative backgrounds

---

## 5.2 Flags Section

Flags appear as:

- Badges  
- Small grouped list  
- Compact spacing

Example:

\[Restricted\]  
\[Pending Review\]  
\[High Risk\]

---

# 6\) Transaction Screen Variant

Transaction screens follow same layout but with:

## Primary Panel:

- Entry Form Card  
- Line Items Card

## Reference Panel:

- Account Summary  
- Real-time balance box

## Sticky Footer:

\[Cancel\]        \[Post Deposit\]

Rules:

- Exactly one primary commit button  
- Status text on left side of footer  
- Void/Reverse in overflow

---

# 7\) Spacing Enforcement

Page Sections:

- 16px separation

Card interior:

- 12–16px padding

Table row:

- 8–10px vertical padding

Field spacing:

- 8–12px vertical gap

Never:

- 32px+ spacing inside workstation views  
- Large decorative whitespace

---

# 8\) Visual Hierarchy Rules

Hierarchy must be established by:

1. Typography (H1 \> H2 \> label)  
2. Border boundaries  
3. Alignment  
4. Grouping

Not by:

- Color blocks  
- Heavy shadow  
- Large rounded shapes

---

# 9\) Component Usage Summary

Header → Page-level actions  
Alert → Compliance/system state  
Primary Panel → Core record data \+ tables  
Reference Panel → Read-only summary \+ balances  
Card → Independent content section  
Box → Financial summary  
Table → Multi-row structured data  
Badge → Status indicator

---

# 10\) Density & Tone

Every record screen should visually communicate:

- Procedural workflow  
- Financial seriousness  
- Controlled interaction  
- Audit traceability

If it looks like a SaaS dashboard, it is wrong.

If it looks like a workstation tool, it is correct.

---

# 11\) Implementation Expectations

All record screens must:

- Follow this structure  
- Use consistent column proportions  
- Avoid layout improvisation  
- Place actions according to Actions Contract  
- Respect spacing profile

Deviations must be intentional and documented.  