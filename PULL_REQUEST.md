# Denomination-Based Cash Entry

## Summary

Adds optional cash denomination breakdown to teller workflows: tellers can record cash by denomination (bills, loose coin, rolled coin) when processing deposits, withdrawals, check cashing, bill payments, misc receipts, vault transfers, and session open/close. Breakdowns are stored as audit metadata and support drawer reconciliation.

## Features

### Cash Count Modal

- **Count button** — Opens a modal to enter quantities by denomination
- **Denomination types** — Bills (two-column layout), Loose Coin, Rolled Coin (paired by face value)
- **Auto-totals** — Bills, Loose, Rolled subtotals; grand total; optional Difference vs. expected amount
- **Validation** — For check cashing (computed payout): Apply blocked until count matches expected

### Workflow Integration

| Workflow        | Cash field                         | Count placement          | Enforcement                         |
|----------------|------------------------------------|--------------------------|-------------------------------------|
| Deposit        | Cash Amount                        | Next to input            | Optional                            |
| Withdrawal     | Cash Amount                        | Next to input            | Optional                            |
| Check cashing  | Cash payout (computed)             | Dedicated row + Count    | Required to match net payout        |
| Bill payment   | Cash (payment split)               | Next to input            | Optional (match entered amount)     |
| Misc receipt   | Cash (payment split)               | Next to input            | Optional (match entered amount)     |
| Vault transfer | Amount (computed from form)        | Next to amount display   | Optional                            |
| Session open   | Opening cash                       | Next to amount           | Required                            |
| Session close  | Closing cash                       | Next to amount           | Required                            |

### UX

- **Modal layout** — Wider (48rem), fixed subtotals row (Bills/Loose/Rolled/Total stay visible while scrolling), sticky Cancel/Apply
- **Input sizing** — Minimum 6rem for qty inputs; grid prevents collapse when modal is narrow

## Technical Changes

### Backend

- **Models:** `CashDenomination`, `DenominationSet`, `DenominationLine` — catalog of denominations, breakdown sets linked to transactions
- **Service:** `DenominationBreakdownService` — persists breakdown from request metadata
- **Committer:** Persists `denomination_lines` when `denomination_breakdown_mode` is :optional or :required
- **Workflow registry:** `denomination_breakdown_mode` per workflow (:optional, :required, :hidden)
- **Migrations:** `create_cash_denominations`, `create_denomination_sets_and_lines`
- **Seeds:** Default US denominations (bills $1–$100; pennies through quarters loose + rolled; halves, dollars optional)

### Frontend

- **Controllers:** `denomination_entry_controller.js` — renders rows, tracks lines, emits `denomination:change`
- **Modal:** `cash_count_modal_controller.js` — opens/closes dialog, applies count, enforces expected amount when set
- **Form controllers:** `onDenominationChange`, `denominationLines` in `getState`, reset on clear
- **Payload:** `appendDenominationLines` appends `denomination_lines` from state for all workflows

### Session Open/Close

- Native form submit with hidden denomination fields (session forms use `use_hidden_fields: true`)
- Other workflows use JS FormData + `appendDenominationLines` to avoid duplicate lines

## Testing

- Model validations (`CashDenomination`, `DenominationSet`, `DenominationLine`)
- `DenominationBreakdownService` persistence
- `Committer` with denomination metadata
- `WorkflowValidator` denomination mode handling
- Teller typed creates including denomination lines

## Checklist

- [x] Cash denomination models and migrations
- [x] Denomination breakdown service and committer integration
- [x] Cash count modal and denomination entry controller
- [x] Count button on deposit, withdrawal, vault transfer, check cashing, bill payment, misc receipt
- [x] Session open/close denomination entry
- [x] Check cashing enforcement (count must match net payout)
- [x] Modal layout (wider, fixed subtotals, usable inputs)
- [x] Tests passing
