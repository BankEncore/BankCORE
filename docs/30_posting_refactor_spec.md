# BankCORE — Posting Decomposition Specification

## Status
This document defines the implementation specification and milestone plan for decomposing posting responsibilities into smaller, testable components while preserving current behavior.

This document is implementation-facing and must remain aligned with:
- [docs/10_phase1_spec.md](docs/10_phase1_spec.md) (authoritative product scope)
- [docs/10_phase1_status.md](docs/10_phase1_status.md) (implementation snapshot)

---

## 1) Purpose
Reduce coupling and complexity in posting orchestration by splitting responsibilities currently concentrated across:
- `Posting::Engine`
- `PostingRequestBuilder`
- `TellerPostingExecution`
- `TransactionsController#validate`
- `posting_form_controller.js`

The decomposition must preserve all financial and operational invariants.

---

## 2) Non-negotiable invariants
1. **Balanced legs** are mandatory for every post: $\sum \text{debits} = \sum \text{credits}$.
2. **Idempotency** by request id must remain unchanged.
3. **Cash controls** must remain enforced (session/drawer prerequisites for cash-affecting workflows).
4. **Approval flow** must remain policy-driven, token-verified, and auditable.
5. **Receipt metadata compatibility** must be preserved for already-implemented types.
6. **No route contract breakage** during decomposition milestones.

---

## 3) Current responsibility map (baseline)
### 3.1 Transport/orchestration
- `app/controllers/concerns/teller_posting_execution.rb`
- `app/controllers/teller/transactions_controller.rb`

### 3.2 Request shaping + generated entries
- `app/controllers/concerns/posting_request_builder.rb`

### 3.3 Runtime posting + persistence + effects
- `app/services/posting/engine.rb`

### 3.4 UI-side transaction logic (currently duplicated with server)
- `app/javascript/controllers/posting_form_controller.js`
- `app/views/teller/dashboard/_posting_workspace.html.erb`

---

## 4) Workflow field specification (target UX and validation model)
The following workflow contracts define required transaction prompts and data expectations.

## 4.1 Deposit
- Account Entry/Select
- Cash In
- Check(s)
- Cash Back

## 4.2 Withdrawal
- Bank Account
- Withdrawal Amount
- Fee

## 4.3 Transfer
- Source (funding account)
- Destination (deposit account)
- Amount
- Fee

## 4.4 Cash Check
- Party
- Related Account (optional)
- Check detail(s)
- Fee

## 4.5 Bank Draft
- Draft amount
- Fee
- Funding source: Account, Cash, Check
- Funding details:
  - Account
  - Cash In
  - Check(s)
- Payee
- Instrument Number

## 4.6 Vault Transfer
- Transfer From
- Transfer To
- Amount

## 4.7 Bill Payment
- Payee
- Payee Account/Reference
- Payment Amount
- Fee
- Funding details:
  - Account
  - Cash In
  - Check(s) In

## 4.8 Misc. Receipt
- Receipt type
- Amount
- Funding details:
  - Account
  - Cash In
  - Check(s) In

---

## 5) Target architecture
## 5.1 Posting engine role (end state)
`Posting::Engine` becomes a thin orchestrator:
1. Normalize request
2. Validate workflow contract
3. Build posting recipe (entries + metadata)
4. Apply posting policies/invariants
5. Commit persistence atomically
6. Apply side effects (cash movements, audit hooks)

## 5.2 New decomposition units
- `Teller::WorkflowRegistry` (workflow definitions)
- `Posting::WorkflowValidator` (required/conditional field rules)
- `Posting::RecipeBuilder` (server-authoritative entries and metadata)
- `Posting::Committer` (DB transaction boundary)
- `Posting::Effects::*` (cash movement + future side effects)

## 5.3 Authority model
- Server-side workflow rules are canonical.
- UI is generated/mirrors server rules; UI is never the source of truth.

---

## 6) Realtime UX contract
This section defines runtime UX behavior that must be preserved or improved during decomposition.

## 6.1 Recalculation triggers
Recalculation must execute on every relevant user input event:
- Transaction type changes
- Amount changes
- Fee changes
- Funding source/mode changes
- Account/cash/check entry changes
- Check row add/remove and check amount changes

## 6.2 Recalculation outputs
Each recalculation cycle must update, in one pass:
- Effective transaction amount
- Debit total
- Credit total
- Imbalance amount
- Cash impact
- Projected drawer value
- Posting readiness state and blocking reason
- Approval threshold warning visibility

## 6.3 Field-state contract
For the selected workflow, UI must enforce:
- Visible fields = workflow contract fields
- Required fields = validator-required fields
- Disabled fields for non-selected workflows
- Conditional requirements (e.g., memo required when reason is "other")

## 6.4 Validation parity
- Realtime UI validation is advisory and must mirror server rules.
- Server validation remains authoritative for post/validate endpoints.
- If UI and server disagree, server response drives final state and user messaging.

## 6.5 Response and messaging contract
On validate/post response:
- Success path updates status badges and receipt panel deterministically.
- Blocking path renders explicit user-facing reason without clearing user input.
- Approval-required path preserves request correlation and moves to approval state.

## 6.6 Performance and responsiveness
- Recalculation must remain local/in-memory and synchronous for visible updates.
- No network call is required for totals/balance state updates.
- Typing latency should remain imperceptible for standard transaction forms.

## 6.7 Reference integration
Realtime transaction updates must continue to feed:
- Reference panel refresh events
- Header/totals badges
- Approval-panel trigger state

---

## 7) Milestone plan
## M0 — Characterization lock
Goal: freeze current behavior with tests before extraction.
- Ensure coverage around idempotency, balancing, prerequisites, approvals, metadata, receipts.
- Gate: no changes in behavior observed under existing suites.

## M1 — Workflow registry + validator extraction
Goal: centralize field contracts without changing posting semantics.
- Add `WorkflowRegistry` definitions for implemented types first.
- Add `WorkflowValidator` and integrate with validate/post request path.
- Keep legacy entry generation in place.

## M2 — Recipe extraction (server-authoritative)
Goal: move generated entries/metadata out of controller concern into dedicated builders.
- Extract per-transaction recipe logic incrementally.
- Keep output shape identical to current persisted model.

## M3 — Engine slimming
Goal: split `Posting::Engine` responsibilities.
- Extract commit boundary (`Posting::Committer`).
- Extract side effects (`Posting::Effects::CashMovementRecorder`).
- Keep engine as orchestrator only.

## M4 — UI/server contract alignment
Goal: remove rule duplication and inconsistent prompts.
- Ensure `posting_form_controller.js` renders workflow fields from canonical contract.
- Keep current endpoints and JSON structures stable.

## M5 — Cleanup and hardening
Goal: remove legacy paths and duplicate logic.
- Remove transitional fallback paths after parity is proven.
- Document final architecture and ownership boundaries.

---

## 8) Acceptance criteria
1. Engine orchestrator has no transaction-type-specific branching logic.
2. All implemented workflows validate against one canonical contract.
3. Recipe generation lives outside controllers.
4. Idempotency, balance, and prerequisite behavior are unchanged from baseline tests.
5. Receipts for existing transactions remain backward compatible.
6. Full CI remains green at each milestone boundary.
7. Realtime totals, balance, and readiness state remain functionally equivalent or better.

---

## 9) Test and verification gates
At every milestone:
- `bin/rubocop`
- `bin/rails test test/services/posting/engine_test.rb`
- `bin/rails test test/controllers/teller/postings_controller_test.rb test/controllers/teller/posting_checks_controller_test.rb`
- `bin/rails test test/controllers/teller/transactions_controller_test.rb test/controllers/teller/typed_creates_controller_test.rb test/controllers/teller/receipts_controller_test.rb`
- `bin/ci`

---

## 10) Risks and mitigations
## 10.1 UI/server logic drift
Risk: inconsistent prompts/requirements between JS and server.
Mitigation: canonical workflow contract and server-first validation.

## 10.2 Prerequisite policy drift
Risk: drawer/session rules diverge between controller and engine.
Mitigation: centralize policy checks and keep integration tests for transfer/vault edge-cases.

## 10.3 Metadata schema regressions
Risk: receipts/history break if metadata keys change.
Mitigation: explicit backward-compatibility checks in receipt tests.

## 10.4 Large-bang refactor risk
Risk: wide change creates hidden regressions.
Mitigation: milestone extraction with characterization gates and small reversible commits.

---

## 11) Implementation notes
- This spec does not mark new product scope as implemented.
- Any future workflow additions (Bill Payment, Misc. Receipt) remain subject to Phase scope decisions.
- During decomposition, prioritize preserving behavior over internal elegance.
