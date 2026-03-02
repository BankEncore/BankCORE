# Add cached ledger balance on accounts

## Summary

Replaces on-read `SUM(account_transactions)` with a cached `ledger_balance_cents` column on `accounts`, updated atomically at posting commit. Balance reads become O(1); source of truth remains the immutable ledger.

## Motivation

Account balance was recomputed on every page view via:
```ruby
credits = account_transactions.where(direction: "credit").sum(:amount_cents)
debits = account_transactions.where(direction: "debit").sum(:amount_cents)
credits - debits
```

This is expensive as transaction history grows. A cached balance updated at commit time provides:

- O(1) reads for account and party views
- Same accuracy and auditability (ledger is authoritative; cache is derivable)
- Operational control via rebuild/validate tools

## Changes

### Schema

- `accounts.ledger_balance_cents` (integer, NOT NULL, default 0)
- `accounts.ledger_balance_updated_at` (datetime, nullable)

### New files

- **`app/services/posting/ledger_balance_updater.rb`** — Accepts legs, computes per-account deltas (skips internal refs: `cash:`, `check:`, `income:`, etc.), normalizes `acct:` prefix, applies deltas with row locking
- **`app/services/ledger_balance_tasks.rb`** — Rebuild and validate logic
- **`lib/tasks/ledger_balance.rake`** — `rake ledger:rebuild_balances` (repairs by default; `REPAIR=false` to report only), `rake ledger:validate_balances`
- **`test/services/posting/ledger_balance_updater_test.rb`**
- **`test/services/ledger_balance_tasks_test.rb`**

### Modified files

- **`Posting::Committer`** — Calls `LedgerBalanceUpdater` after persisting legs; normalizes `account_reference` when resolving `account_id` (handles `acct:` prefix)
- **`Posting::ReversalService`** — Same updater call and account reference normalization
- **`Account#balance_cents`** — Returns `ledger_balance_cents`
- **`Teller::AccountReferenceSnapshot`** — Uses `account.ledger_balance_cents` when account exists; uses SUM for internal refs (e.g. `cash:DRAWER1`)
- **`shared/accounts/_balance_and_history.html.erb`** — Adds "As of" timestamp from `ledger_balance_updated_at`
- **`csr/accounts/_summary_strip.html.erb`** — Adds "As of" timestamp

### Safety

- Balance updates run **inside the same DB transaction** as posting; no partial commits
- Row locking (`Account.where(...).lock`) prevents race conditions with concurrent posts
- Reversals apply equal-and-opposite deltas via the same updater
- Rebuild task recomputes from authoritative ledger and can repair mismatches
- Validate task reports diffs for CI or nightly monitoring

## Deploy steps

1. Run migration
2. Run `rake ledger:rebuild_balances` once to backfill existing accounts

## Testing

- `bin/ci` passes
- LedgerBalanceUpdater: 9 tests
- LedgerBalanceTasks: 3 tests
- Committer, ReversalService, Account, AccountReferenceSnapshot tests updated for cached balance
