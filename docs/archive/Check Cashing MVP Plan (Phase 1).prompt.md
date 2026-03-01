# Check Cashing MVP Plan (Phase 1)

## Scope + Defaults
- Scope authority: `docs/10_phase1_spec.md`
- Status tracking: `docs/10_phase1_status.md`
- MVP target: implement **check cashing** as a cash-affecting typed transaction using existing posting primitives.

## Locked MVP Assumptions (for immediate start)
1. Eligibility: support both customer and non-customer via one flow (`presenter_type` metadata).
2. Authoritative amount: `teller_transactions.amount_cents = net_cash_payout_cents`.
3. Fee model: optional single fee (`fee_cents`, default 0).
4. ID capture: required fields are `id_type` + `id_number`; validation is capture-level (presence/format only).
5. Approval: keep current threshold-based policy for MVP.

## Posting Recipe (MVP)
- Inputs:
  - `check_amount_cents`
  - `fee_cents` (optional)
  - `settlement_account_reference` (where check value settles)
  - cash account derived from assigned drawer (`cash:<drawer.code>`)
- Derived:
  - `net_cash_payout_cents = check_amount_cents - fee_cents`
  - require `net_cash_payout_cents > 0`
- Legs:
  - Debit `settlement_account_reference` by `check_amount_cents`
  - Credit `cash:<drawer.code>` by `net_cash_payout_cents`
  - Credit `fee_income_account_reference` by `fee_cents` when `fee_cents > 0`
- Invariants:
  - Balanced debits == credits
  - Drawer required (cash-affecting)
  - Cash movement direction for payout is `out` with amount `net_cash_payout_cents`

## Sprint Checklist (Execution Order)

### Phase 0 — Contracts (must pass first)
- [ ] Add `check_cashing` to transaction type allowlists.
  - Files:
    - `app/models/teller_transaction.rb`
    - `app/controllers/teller/transactions_controller.rb`
- [ ] Add/confirm typed routing for check cashing.
  - File: `config/routes.rb`
- [ ] Add typed controller for create path.
  - File: `app/controllers/teller/check_cashings_controller.rb` (new)
- Acceptance:
  - [ ] App recognizes `check_cashing` as valid transaction type.
  - [ ] Typed endpoint resolves and rejects malformed payloads.

### Phase 1 — Server posting pipeline
- [ ] Extend request builder for check-cashing entries + metadata.
  - File: `app/controllers/concerns/posting_request_builder.rb`
- [ ] Permit and pass check-cashing params into execution layer.
  - File: `app/controllers/concerns/teller_posting_execution.rb`
- [ ] Mark check cashing as cash-affecting in prerequisites.
  - File: `app/controllers/concerns/posting_prerequisites.rb`
- [ ] Ensure engine creates correct cash out movement for check cashing.
  - File: `app/services/posting/engine.rb`
- Acceptance:
  - [ ] Posting creates balanced package and idempotent behavior remains unchanged.
  - [ ] `CashMovement` created as `out` for net payout.

### Phase 2 — UI typed flow
- [ ] Add check-cashing option and form fields to workspace.
  - File: `app/views/teller/dashboard/_posting_workspace.html.erb`
- [ ] Add check-cashing payload/recalc handling in Stimulus.
  - File: `app/javascript/controllers/posting_form_controller.js`
- [ ] Allow typed page rendering.
  - File: `app/controllers/teller/transaction_pages_controller.rb`
- Acceptance:
  - [ ] Teller can complete check-cashing entry with out-of-balance prevention.
  - [ ] Drawer context remains read-only and non-editable per transaction.

### Phase 3 — Auth, receipt, and audit completion
- [ ] Add permission gate for check-cashing create.
  - File: `app/policies/teller/posting_policy.rb`
- [ ] Seed permission key(s).
  - File: `db/seeds.rb`
- [ ] Render check-cashing metadata on receipt view.
  - File: `app/views/teller/receipts/show.html.erb`
- Acceptance:
  - [ ] Authorized teller can post; unauthorized user blocked.
  - [ ] Receipt shows payout, check details, fee, and request/session context.

### Phase 4 — Test gates (required before merge)
- [ ] Controller tests for typed flow, prerequisites, and approvals.
  - Location: `test/controllers/teller/*`
- [ ] Service tests for engine cash movement + invariants.
  - File: `test/services/posting/engine_test.rb`
- [ ] Receipt test coverage for rendered metadata.
  - Location: `test/controllers/teller/receipts_controller_test.rb` (or equivalent)
- [ ] Run lint and targeted tests.
  - Commands:
    - `RAILS_ENV=test bin/rails db:test:prepare`
    - `RAILS_ENV=test bin/rails test ...`
    - `bin/rubocop`
- Acceptance:
  - [ ] New tests pass.
  - [ ] No regressions in existing teller posting tests.

## Risks and Mitigations
- Risk: ambiguous accounting recipe (especially fee leg account).
  - Mitigation: lock `fee_income_account_reference` constant/config before coding phase 1.
- Risk: accidental drift in amount semantics.
  - Mitigation: assert `teller_transaction.amount_cents == net_cash_payout_cents` in tests.
- Risk: policy mismatch with branch/workstation scoping.
  - Mitigation: mirror existing `posting.create` permission pattern and add explicit authorization tests.

## Done Criteria (MVP)
- [ ] Check-cashing transaction posts through typed flow.
- [ ] Legs are balanced and request id idempotency remains intact.
- [ ] Drawer prerequisite enforced and cash movement recorded as cash outflow.
- [ ] Metadata is auditable and visible on receipt.
- [ ] Tests + RuboCop pass.
