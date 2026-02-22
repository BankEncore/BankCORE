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
