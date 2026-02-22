# Changelog

## 2026-02-22

### Commit 27532c2
BankCORE now uses a clearer teller setup progression with dedicated workstation-style navigation. Branch/workstation setup is handled on Context, teller session and drawer actions are consolidated under Session, and transaction prerequisites now guide users with explicit next-step messaging while preserving return-to behavior after setup completion. The teller shell now has a dedicated layout and standardized command bar ordering with planned workflows shown as disabled placeholders, and a minimal Ops shell scaffold was added for future reporting surfaces. These updates were validated by teller controller tests and full CI before merge.

#### Files touched
- `app/controllers/application_controller.rb`
- `app/controllers/concerns/posting_prerequisites.rb`
- `app/controllers/teller/base_controller.rb`
- `app/controllers/teller/contexts_controller.rb`
- `app/controllers/teller/teller_sessions_controller.rb`
- `app/controllers/teller/transaction_pages_controller.rb`
- `app/controllers/teller/deposits_controller.rb`
- `app/controllers/teller/withdrawals_controller.rb`
- `app/controllers/teller/transfers_controller.rb`
- `app/controllers/teller/check_cashings_controller.rb`
- `app/controllers/teller/postings_controller.rb`
- `app/controllers/teller/posting_checks_controller.rb`
- `app/controllers/teller/transactions_controller.rb`
- `app/controllers/teller/approvals_controller.rb`
- `app/controllers/teller/account_references_controller.rb`
- `app/controllers/teller/dashboard_controller.rb`
- `app/controllers/teller/receipts_controller.rb`
- `app/controllers/ops/base_controller.rb`
- `app/controllers/ops/dashboard_controller.rb`
- `app/views/layouts/application.html.erb`
- `app/views/layouts/teller.html.erb`
- `app/views/teller/shared/_command_bar.html.erb`
- `app/views/teller/shared/_flash_banners.html.erb`
- `app/views/teller/contexts/show.html.erb`
- `app/views/teller/teller_sessions/new.html.erb`
- `app/views/teller/dashboard/index.html.erb`
- `app/views/teller/transaction_pages/show.html.erb`
- `app/views/teller/receipts/show.html.erb`
- `app/views/ops/dashboard/index.html.erb`
- `config/routes.rb`
- `docs/notes/working_notes.md`
- `test/controllers/teller/dashboard_controller_test.rb`
- `test/controllers/teller/transaction_pages_controller_test.rb`
- `test/controllers/teller/posting_checks_controller_test.rb`
- `test/controllers/teller/teller_sessions_controller_test.rb`

### Commit 183b1ab
Fixed a teller context regression where selecting a branch did not make workstation selection usable. The context form now supplies branch-to-workstation mappings to Stimulus, repopulates workstation options when branch changes, and preserves valid saved context when available. A controller regression test was added to ensure the client payload is present for dependent workstation selection.

#### Files touched
- `app/controllers/teller/contexts_controller.rb`
- `app/javascript/controllers/teller_context_controller.js`
- `app/views/teller/contexts/show.html.erb`
- `app/views/teller/dashboard/_session_context_card.html.erb`
- `test/controllers/teller/contexts_controller_test.rb`

### Commit 6c0b4d1
Implemented Phase 1 Vault Transfer end-to-end in teller workflows, including typed route/controller support, direction-aware validation and posting generation, policy/permission wiring, UI entry forms, receipt metadata rendering, and regression coverage. The flow supports drawer-to-vault, vault-to-drawer, and vault-to-vault transfers with idempotent posting behavior, cash impact handling, and compatibility with existing approval and posting infrastructure.

#### Files touched
- `app/controllers/concerns/posting_prerequisites.rb`
- `app/controllers/concerns/posting_request_builder.rb`
- `app/controllers/concerns/teller_posting_execution.rb`
- `app/controllers/teller/dashboard_controller.rb`
- `app/controllers/teller/transaction_pages_controller.rb`
- `app/controllers/teller/transactions_controller.rb`
- `app/controllers/teller/vault_transfers_controller.rb`
- `app/javascript/controllers/posting_form_controller.js`
- `app/models/teller_transaction.rb`
- `app/policies/teller/posting_batch_policy.rb`
- `app/policies/teller/posting_policy.rb`
- `app/services/posting/engine.rb`
- `app/views/teller/dashboard/_posting_workspace.html.erb`
- `app/views/teller/dashboard/index.html.erb`
- `app/views/teller/receipts/show.html.erb`
- `app/views/teller/shared/_command_bar.html.erb`
- `app/views/teller/transaction_pages/show.html.erb`
- `config/routes.rb`
- `db/seeds.rb`
- `docs/10_phase1_status.md`
- `test/controllers/teller/receipts_controller_test.rb`
- `test/controllers/teller/transaction_pages_controller_test.rb`
- `test/controllers/teller/transactions_controller_test.rb`
- `test/controllers/teller/typed_creates_controller_test.rb`

### Commit 0c22647
Removed redundant frontend `required_fields` OR-gating in the teller posting Stimulus controller. Requirement gating is now handled exclusively through workflow policy helpers for primary/counterparty/cash/settlement account requirements, reducing duplicated client rule paths while preserving behavior.

#### Files touched
- `app/javascript/controllers/posting_form_controller.js`

### Commit b2ddc4e
Updated workflow schema generation to derive `required_fields` from canonical workflow policy metadata plus workflow-specific payload requirements. This removes duplicate rule declarations in the registry and reduces policy/schema drift risk while preserving compatibility for existing consumers.

#### Files touched
- `app/services/teller/workflow_registry.rb`

### Commit 161cd86
Clarified the posting decomposition architecture contract: policy-oriented workflow keys are canonical, and `required_fields` is compatibility output derived from those keys rather than an independently authored source.

#### Files touched
- `docs/30_posting_refactor_spec.md`

### Commit dd081c1
Recorded the latest posting decomposition cleanup increments in the Phase 1 status snapshot to keep implementation tracking aligned with recent schema-contract and frontend policy-gating changes.

#### Files touched
- `docs/10_phase1_status.md`
