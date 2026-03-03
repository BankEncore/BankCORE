# Account reference implementation — current state

**Project:** BankCORE  
**Scope:** Documented behavior in `app/`, not future plans  
**Date:** 2026-03-03

---

## Overview

Posting legs store a string `account_reference` (e.g., `acct:12345678`, `cash:D01`, `income:check_cashing_fee`). The system now uses a typed reference registry (`ledger_references` table) for resolution and validation. References must resolve before posting; unknown references are rejected. Customer account references are normalized to canonical `acct:<account_number>` form at the boundary.

This document describes what is implemented today.

---

## 1. AccountReferenceParser (typed parsing)

**Location:** `app/services/posting/account_reference_parser.rb`

Parses a raw reference string into structured fields. This is a **parse-time derivation** — it does not look up references in a table.

### Reference prefixes and types

| Prefix | reference_type | reference_identifier |
|--------|----------------|----------------------|
| `cash:` | `cash_location` | Location code (e.g., `D01`, `V01`) |
| `check:` | `check_clearing` | Full reference; routing/account/number in dedicated fields |
| `income:` | `income` | Fee/income code (e.g., `check_cashing_fee`, `variance`) |
| `official_check:` | `liability` | Liability subtype (e.g., `outstanding`) |
| `expense:` | `expense` | Expense code (e.g., `cash_short`) |
| (bare or `acct:`) | `customer_account` | Account number |

### INTERNAL_PREFIXES

```ruby
INTERNAL_PREFIXES = %w[cash: check: income: official_check: expense:]
```

Used elsewhere to distinguish “internal” references (no Account row) from customer accounts (have Account row).

### API

```ruby
Posting::AccountReferenceParser.parse("cash:D01")
# => { reference_type: "cash_location", reference_identifier: "D01", ... }

Posting::AccountReferenceParser.parse("acct:12345678")
# => { reference_type: "customer_account", reference_identifier: "12345678", ... }

Posting::AccountReferenceParser.parse("check:021:456:789", metadata: { "check_type" => "transit" })
# => { reference_type: "check_clearing", ..., check_routing_number: "021", check_account_number: "456", check_number: "789", check_type: "transit" }
```

For `check:` references, `metadata` may supply `check_type` (transit, on_us, bank_draft) when it is not encoded in the string.

---

## 2. Typed columns on posting_legs

**Schema:** `posting_legs` has:

- `account_reference` (string, NOT NULL) — canonical stored value
- `reference_type` (string, nullable)
- `reference_identifier` (string, nullable)
- `check_routing_number`, `check_account_number`, `check_number`, `check_type` (strings, nullable)

### Population

1. **On commit:** `Posting::RecipeBuilder` enriches each entry with parsed fields before `Posting::Committer` persists legs. The Committer writes both `account_reference` and the typed fields to `posting_legs`.

2. **Historical data:** Migration `BackfillPostingLegStructuredColumns` backfills `reference_type`, `reference_identifier`, and check columns for existing legs by parsing `account_reference`.

### Relation to Option A/B

These columns are **denormalized typed projections** — derived from parsing the string, not from a registry lookup. They support display and grouping but do not provide referential integrity.

---

## 3. ReferenceLabelMapper (display)

**Location:** `app/services/posting/reference_label_mapper.rb`

Produces human-readable labels for legs using `reference_type` and `reference_identifier`, with fallback to `account_reference`.

### Behavior

- Uses `reference_type` when present; otherwise falls back to raw `account_reference`.
- For `cash_location`: looks up `CashLocation` by branch + code; shows “Drawer X” or “Vault X” when found.
- For `customer_account`: masks identifier (e.g., “Account xxxx5678”).
- For `income`: uses `INCOME_LABELS` mapping (check_cashing_fee, transfer_fee, draft_fee, etc.).
- For `check_clearing`: appends “(transit)”, “(on us)”, or “(bank draft)” from `check_type`.

### API

```ruby
Posting::ReferenceLabelMapper.label_for(leg, branch: branch)
```

Used in views (e.g., receipt display, ledger views) via `application_helper`.

---

## 4. LedgerBalanceUpdater (balance updates)

**Location:** `app/services/posting/ledger_balance_updater.rb`

Updates `Account.ledger_balance_cents` for customer-account legs only. It **parses strings inline**; it does not use a registry.

### Logic

1. For each leg hash: `account_reference` → `account_number` via `normalize_customer_account_ref` (strips `acct:` prefix).
2. Skips legs whose reference starts with any `INTERNAL_PREFIXES` (cash, check, income, official_check, expense).
3. Locks `Account` rows and increments `ledger_balance_cents` by the leg’s signed amount.

No validation that the account exists; missing accounts are simply skipped (delta not applied).

---

## 5. Ledger reference registry (Option A)

**Location:** `app/models/ledger_reference.rb`, `app/services/ledger_references/resolver.rb`

A canonical registry table `ledger_references` maps reference strings to typed entities. The `LedgerReferences::Resolver` looks up references (normalizing bare account numbers to `acct:` form) and returns a `LedgerReference` or raises `UnresolvedReference`.

### Registry population

- **Account** and **CashLocation** models register on create (callback).
- **MiscReceiptType** and **BillPayee** register their `income_account_reference` / `liability_account_reference` on save.
- Backfill migration seeds existing data.
- **check:** references use lazy registration on first resolve.

### Validation

`Posting::ReferenceValidator` runs in `Posting::Engine` before balance check and commit. Any unresolved reference raises `Posting::Engine::Error`.

---

## 6. What is not implemented (Option B/C)

| Capability | Status |
|------------|--------|
| `posting_legs.ledger_reference_id` FK | Not implemented (Option B) |
| Full `posting_accounts` normalization | Not implemented (Option C) |
| Trial balance / GL reporting UI | Not implemented |

---

## 7. Reference format conventions (in use)

These are **conventions** in code and config, not enforced:

- Customer: `acct:<account_number>` or bare `account_number`
- Cash: `cash:<location_code>` (e.g., `cash:D01`)
- Check clearing: `check:<routing>:<account>:<number>`
- Income: `income:<fee_code>` (e.g., `income:check_cashing_fee`)
- Liability: `official_check:<subtype>` (e.g., `official_check:outstanding`)
- Expense: `expense:<code>` (e.g., `expense:cash_short`)

Config tables (`MiscReceiptType.income_account_reference`, `BillPayee.liability_account_reference`) also store these strings.

---

## 8. Data flow summary

```
RecipeBuilder
  → AccountReferenceParser.parse(account_reference)
  → canonicalize_account_reference (customer → acct:)
  → Enriched entries (account_reference, reference_type, reference_identifier, check_*)

Posting::Engine
  → ReferenceValidator.call(legs) — LedgerReferences::Resolver for each leg
  → BalanceChecker, Committer

Committer
  → PostingLeg.create!(account_reference, reference_type, reference_identifier, ...)
  → LedgerBalanceUpdater.call(legs)

LedgerBalanceUpdater
  → LedgerReferences::Resolver.call(reference) per leg
  → If ref_type == "customer_account" && account_id.present? → increment! Account

Display
  → ReferenceLabelMapper.label_for(leg) — uses reference_type / reference_identifier
```

---

## 9. Related files

| File | Role |
|------|------|
| `app/models/ledger_reference.rb` | Registry model |
| `app/services/ledger_references/resolver.rb` | Resolve reference → LedgerReference |
| `app/services/posting/reference_validator.rb` | Validate legs before commit |
| `app/services/posting/account_reference_parser.rb` | Parse reference strings to typed hash |
| `app/services/posting/reference_label_mapper.rb` | Human-readable labels for legs |
| `app/services/posting/recipe_builder.rb` | Enriches entries, canonicalizes customer refs |
| `app/services/posting/committer.rb` | Persists legs with typed columns |
| `app/services/posting/ledger_balance_updater.rb` | Updates balances via Resolver |
| `app/helpers/application_helper.rb` | Uses ReferenceLabelMapper in views |
| `db/migrate/*_create_ledger_references.rb` | Registry table |
| `db/migrate/*_backfill_ledger_references.rb` | Initial seed |
