# Teller Bill Payment Transaction

## Summary

Implements the Bill Payment workflow (L5-WF-06): tellers can accept payment from a customer to remit to a biller/payee, with funding via account debit, cash, or mixed. Produces balanced posting batches, receipt blocks, and audit metadata.

## Features

### Transaction Flow

- **Payee selection** — Choose from configured Bill Payees (admin-managed) with liability account and default fee
- **Payee reference** — Required account or reference number with the payee
- **Payment amount & fee** — Payment amount > 0; fee optional with payee default
- **Funding methods** — Cash, Account transfer, or Mixed (cash + checks + account = total due)

### Entry Form

- Now Serving (Party) and Primary Account (optional for account-funded payments)
- Payee dropdown, payee reference, memo (required when payee mandates)
- Payment amount and fee inputs (currency-input)
- Cash, Check, and Account transfer split — must balance to total due

### Posting & Audit

- Balanced double-entry posting to payable liability and funding sources
- Cash movement recorded when cash funding used
- Receipt partial with payee, reference, amounts, funding breakdown
- Idempotency via `request_id` prevents duplicate postings

### Admin

- Bill Payees CRUD: code, name, liability account reference, default fee, memo required flag

## Bug Fixes (Payload & Validation)

Two fixes address validation errors when posting:

1. **`posting_payload.js`** — Bill payment was missing from `appendServedPartyPayload` and had no `appendBillPaymentPayload`. Added `bill_payment` to served-party list and implemented `appendBillPaymentPayload` so `party_id`, `payee_id`, `payee_reference`, `payment_cents`, `fee_cents`, `amount_cents`, `liability_account_reference`, `memo`, `bill_payment_cash_cents`, and `bill_payment_account_cents` are sent from form state.

2. **`TransactionsController#validation_params`** — Pre-submit validation endpoint did not permit bill payment params, so they were filtered out before reaching `WorkflowValidator`. Added `payee_id`, `payee_reference`, `payment_cents`, `liability_account_reference`, `bill_payment_cash_cents`, `bill_payment_account_cents` to `validation_params`.

## Technical Changes

### Backend

- **Model:** `BillPayee` — code, name, liability_account_reference, default_fee_amount_cents, memo_required
- **Recipe:** `BillPaymentRecipe` — builds legs for liability, funding (account/cash/checks), fee income
- **Validator:** `WorkflowValidator` — `validate_bill_payment` checks payee, reference, amounts, balance
- **Controller:** `BillPaymentsController` — new/create with `execute_posting(forced_transaction_type: "bill_payment")`
- **Policy:** `PostingPolicy#bill_payment_create?`; `BillPayeePolicy` for admin

### Frontend

- **Form:** `_bill_payment_form.html.erb` — served party, primary account, payee/reference, amounts, cash/check/account split
- **Controller:** `bill_payment_form_controller.js` — `getState`, `billPaymentAmounts`, `recalculate`, balance validation
- **Payload:** `appendBillPaymentPayload` in `posting_payload.js`; bill_payment in `appendServedPartyPayload` list

### Routes

- `GET/POST /teller/bill_payments`
- `GET /teller/transactions/bill_payment` (transaction page)
- Admin: `/admin/bill_payees`

## Testing

- `BillPayee` model validations
- `WorkflowValidator` bill payment (payee, reference, amounts, balance)
- `BillPaymentRecipe` and recipe builder
- `CashMovementRecorder` bill payment + reversal
- Admin Bill Payees CRUD
- Teller typed creates (bill_payment)

## Checklist

- [x] Bill Payee model and migration
- [x] Posting recipe and workflow validator
- [x] Bill payment form and Stimulus controller
- [x] Payload and validation params include bill payment fields
- [x] Receipt partial and cash movement recording
- [x] Admin Bill Payees CRUD
- [x] Seeds for bill payees
- [x] Tests passing
