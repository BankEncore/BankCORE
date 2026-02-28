# tx:recalc Event Contract

Defines the payload structure for the `tx:recalc` custom event emitted during teller transaction form edits. All consumers (reference_panel, live_account_panel, tx_shell, etc.) derive displayed data from this event; no additional form reads.

## When Emitted

- On any form input/change that triggers `posting_form#recalculate`
- After `buildEntries`, `computeTotals`, and cash-impact logic have run

## Payload Fields

| Field | Type | Description |
|-------|------|-------------|
| `transactionType` | string | `deposit`, `withdrawal`, `transfer`, `draft`, `check_cashing`, `vault_transfer` |
| `entries` | Array | `{ side, account_reference, amount_cents }[]` from `buildEntries` |
| `primaryReference` | string | Primary account reference |
| `counterpartyReference` | string | Counterparty account (transfers only) |
| `cashReference` | string | Cash account reference |
| `requestId` | string | Request ID |
| `partyId` | string | Party ID (check cashing) |
| `cashAmountCents` | number | Displayed cash amount (or net payout for check cashing) |
| `checkAmountCents` | number | Check cashing check total |
| `feeCents` | number | Check cashing fee |
| `draftAmountCents` | number | Draft amount |
| `draftFeeCents` | number | Draft fee |
| `checkSubtotalCents` | number | Sum of check amounts |
| `totalAmountCents` | number | Effective total |
| `debitTotal` | number | Sum of debit legs |
| `creditTotal` | number | Sum of credit legs |
| `imbalanceCents` | number | \|debit - credit\| |
| `cashImpactCents` | number | Net drawer impact |
| `projectedDrawerCents` | number | Opening + cash impact |
| `readyToPost` | boolean | Form ready to submit |
| `blockedReason` | string | Reason when not ready |

## Consumers

- `reference-panel#refresh` — Transaction Snapshot, Amounts, Cash Impact, Posting Readiness
- `live-account-panel#refresh` — Account snapshot
- `tx-shell#handleRecalc` — Shell state
