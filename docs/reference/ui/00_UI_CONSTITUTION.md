# UI Contract — Layout & Visual Components

(Badges, Boxes, Tables, Cards, Panels)

Audience: BankCORE workstation UI (Teller / Ops / CSR) Purpose: Standardize when and where to use badges, tables, cards, panels, alerts, and related layout primitives.

This document complements:

- docs/ui/contracts/actions.md

---

# 1\) Core Principle

BankCORE is a workstation-style application. It is:

- Dense  
- Structured  
- Predictable  
- Hierarchical

Visual structure must come from:

- Alignment  
- Spacing  
- Borders  
- Typography

Not from:

- Excessive color  
- Heavy card stacking  
- Marketing-style elevation

---

# 2\) Tables

## 2.1 When to Use Tables

Use tables when displaying:

- Transaction history  
- Account transactions  
- Teller activity  
- Posting legs  
- Batch contents  
- Reports  
- Lists with sortable/filterable columns  
- Anything financial and row-oriented

If it has columns and numeric alignment → it is a table.

---

## 2.2 Table Rules

- Header row required.  
- Numeric columns right-aligned.  
- Monetary values use tabular numerals.  
- Row actions in rightmost column only.  
- No card-wrapping individual rows.  
- Compact vertical spacing (workstation density).

Avoid:

- Nested cards inside table cells.  
- Mixed alignment.  
- Large padding inside financial tables.

---

# 3\) Cards

## 3.1 When to Use Cards

Use cards only to:

- Separate major page sections  
- Contain form groups  
- Contain independent content blocks

Examples:

- Account Details  
- Reference Panel  
- Transaction Entry Form  
- Summary Panel

Cards are NOT for:

- Every row  
- Every data element  
- Financial history lists

---

## 3.2 Card Density Rules

Workstation cards should:

- Use light border  
- Minimal shadow (or none)  
- Tight padding  
- Clear section title

Avoid:

- Stacked “card inside card inside card”  
- Large rounded marketing-style blocks  
- Excess white space

---

# 4\) Panels (Structural Containers)

Panels are structural wrappers that define:

- Group boundaries  
- Vertical rhythm  
- Logical section breaks

Examples:

- Transaction shell  
- Reference side panel  
- Balance summary panel  
- Filter panel

Panels create structure. Cards create contained content.

If it defines layout boundaries → panel. If it contains content → card.

---

# 5\) Boxes (Neutral Containers)

Use simple bordered boxes for:

- Totals summaries  
- Mini-stat blocks  
- Reconciliation summaries  
- Count sheets  
- Compact grouped data

Boxes should be:

- Rectangular  
- Low decoration  
- Subtle border  
- No strong elevation

Boxes are ideal for:

- Cash totals  
- Drawer variance  
- Quick reference metrics

Do NOT use cards for tiny metric blocks.

---

# 6\) Badges

## 6.1 When to Use Badges

Badges are for:

- Status indicators  
- Short categorical labels  
- Risk markers  
- Flags

Examples:

- Active / Closed  
- Pending Approval  
- Out of Balance  
- Supervisor Required  
- Fee Waived  
- Restricted  
- High Risk

Badges must be:

- Short (1–3 words)  
- Inline with text or near label  
- Secondary emphasis, not primary content

---

## 6.2 Badge Rules

Badges are NOT:

- Buttons  
- Primary navigation  
- Containers for long text

Never:

- Use badges to display dollar amounts  
- Use badges as substitutes for section headers

---

## 6.3 Color Discipline

Color usage must be semantic:

- Neutral: informational  
- Warning: needs attention  
- Error: blocked or failed  
- Success: completed/approved  
- Primary: rarely used in badges

Never rely solely on color to convey meaning. Text must communicate state.

---

# 7\) Alerts

Use alerts for:

- Blocking validation errors  
- Compliance warnings  
- Approval required notifications  
- System state issues

Alert rules:

- Place above relevant section  
- Do not scatter multiple small alerts throughout page  
- One consolidated alert region preferred

Avoid:

- Banner spam  
- Permanent warning styling for normal states

---

# 8\) Forms

Forms should:

- Be inside a card  
- Group related fields logically  
- Use section dividers only when necessary  
- Avoid overuse of visual separation

Do not:

- Wrap each field in its own card  
- Use badges for required indicators

Required fields:

- Label \+ subtle marker (not loud red badge)

---

# 9\) Financial Data Presentation

Financial information must:

- Be tabular when multi-row  
- Be boxed when summarized  
- Be aligned consistently  
- Avoid decorative layout

Balance panels:

- Ledger balance  
- Available balance  
- Holds

These belong in structured boxes, not colorful cards.

---

# 10\) Side Panels (Reference Panels)

Reference panels:

- Read-only  
- Structured  
- No heavy visual styling  
- Compact

Used for:

- Account summary  
- Party summary  
- Limits  
- Risk flags

Should not visually overpower entry form.

---

# 11\) Density Standards

Workstation UI must prioritize:

- Scan speed  
- Keyboard use  
- Information density

Avoid:

- Large paddings  
- Marketing-style spacing  
- Excess whitespace between rows

Compact \> Spacious.

---

# 12\) Component Decision Matrix

If you are unsure, use this:

Is it row-based financial data? → Table

Is it a summary block? → Box

Is it a major content section? → Card

Is it structural layout? → Panel

Is it short status text? → Badge

Is it urgent attention? → Alert

---

# 13\) Anti-Patterns

Not allowed:

- Card for every row  
- Color-heavy UI  
- Badge misuse as layout tool  
- Nested cards inside tables  
- Shadow-heavy “dashboard” aesthetic  
- Floating actions inside content blocks

---

# 14\) Workstation Design Priority

BankCORE is:

- Operational  
- Audit-focused  
- Procedural  
- Regulated

Visual design must support:

- Clarity  
- Traceability  
- Hierarchy  
- Consistency

Not:

- Visual novelty  
- Marketing presentation  
- Consumer app aesthetics
