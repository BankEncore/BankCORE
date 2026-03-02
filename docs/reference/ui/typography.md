## DROP-IN SAFE — `docs/ui/contracts/typography_tables.md` (Revised for IBM Plex Sans)

```md id="bankcore-typography-tables-v2"
# BankCORE Typography & Table Standards
(IBM Plex Sans + Tabular Numerals)

Purpose:
Define strict standards for typography, numeric presentation, and tables
using IBM Plex Sans as the primary typeface.

BankCORE uses:

Primary Font:
- IBM Plex Sans (with tabular numerals enabled)

Secondary (Limited Use):
- IBM Plex Mono (only when strict fixed-width alignment is required)

We do NOT rely on IBM Plex Mono for general numeric presentation.
Tabular numerals in IBM Plex Sans are the standard.

---

# 1) Font System

## 1.1 Primary UI Typeface

All UI text uses:

IBM Plex Sans

Including:
- Body text
- Labels
- Buttons
- Section headers
- Tables
- Financial data

Numeric stability is achieved via:
font-variant-numeric: tabular-nums

Not by switching to monospace.

---

## 1.2 When IBM Plex Mono Is Allowed

IBM Plex Mono may be used only for:

- Raw posting references
- System IDs
- Audit logs
- Technical diagnostic views
- Developer-facing data
- Structured multi-column fixed-width exports

It must NOT be used for:
- Ledger balances
- Currency tables
- General financial UI
- Primary account numbers in standard view

Default experience = Plex Sans.

---

# 2) Numeric Standards

All financial numbers must:

- Use IBM Plex Sans
- Enable tabular numerals
- Be right-aligned in tables
- Use consistent decimal precision (2 decimals unless defined otherwise)

Required CSS behavior:

font-variant-numeric: tabular-nums;
font-feature-settings: "tnum" 1;

---

# 3) Currency Formatting Rules

Currency must:

- Always show symbol
- Always show two decimal places
- Use thousands separator
- Show negative clearly

Correct:

$4,250.00
-$125.00

Incorrect:

4250
$4,250
$4,250.0

---

# 4) Table Typography Rules

Tables must:

- Use IBM Plex Sans
- Enable tabular numerals on numeric columns
- Right-align numeric columns
- Keep identifiers visually stable

Column conventions (ledger):

Date | Type | Description | Debit | Credit | Balance | Actions

Numeric columns:
- tabular numerals
- right-aligned
- consistent width

Identifiers:
- tabular numerals
- may remain Sans unless technical view

---

# 5) Balance Presentation

Balance panels must:

- Use IBM Plex Sans
- Enable tabular numerals
- Maintain consistent alignment

Example layout:

Ledger Balance        $4,250.00
Available Balance     $4,100.00
Holds                   $150.00

No large promotional typography.
No marketing-style stat cards.

---

# 6) Identifier Handling

Identifiers include:

- Account number
- Party ID
- Transaction ID
- Posting reference
- Batch number
- Check number

Standard record view:
- IBM Plex Sans
- tabular numerals enabled

Technical view (logs/debug):
- IBM Plex Mono allowed

Masking pattern:

****1234

Must remain consistent across system.

---

# 7) Visual Hierarchy

Hierarchy established by:

- Size
- Weight
- Spacing
- Border grouping

Not by:

- Switching fonts
- Decorative type changes
- Large numeric banners

Typography must feel:

Precise
Stable
Serious
Operational

---

# 8) Density & Readability

Financial tables must:

- Remain readable at 100% zoom
- Remain stable at 125% zoom
- Avoid overly small text
- Preserve alignment integrity

Tabular numerals ensure:

- No horizontal shift when values change
- No column jitter during updates

---

# 9) Prohibited Typography Patterns

Not allowed:

- Using Plex Mono for general ledger display
- Center-aligned currency
- Mixing tabular and proportional numerals in same column
- Large dashboard-style numeric tiles
- Random bolding inside tables
- Decorative font variants

---

# 10) Implementation Requirements

All developers must:

- Enable tabular numerals for currency and numeric columns
- Keep IBM Plex Sans as default UI font
- Restrict IBM Plex Mono to system/technical views
- Maintain consistent alignment conventions

Typography consistency is an internal control safeguard.

---

# 11) Guiding Principle

Financial UI must communicate:

Precision.
Consistency.
Control.

If numbers visually shift or jitter,
the typography is incorrect.

If numeric columns remain visually stable under change,
the typography is correct.
```
