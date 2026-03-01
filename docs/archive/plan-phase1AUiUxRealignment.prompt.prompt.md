## Plan: Phase 1A UI/UX Realignment (DRAFT)

Based on your choices, this plan proceeds with Tailwind-only stabilization now (defer DaisyUI plugin), splits teller UX into transaction-specific flows immediately, and completes remaining Phase 1A UI parity. The goal is to align implemented behavior with the UI standards while preserving current posting/approval contracts and keeping tests green each step. We will first secure CSS/tooling correctness, then move from the current unified workspace to separate Deposit/Withdrawal/Transfer pages using a shared shell, followed by validation/accessibility/account-history completion and sprint handoff artifacts.

**Steps**
1. Stabilize styling pipeline and remove faux Daisy dependencies  
- Verify active stylesheet path in [app/views/layouts/application.html.erb](app/views/layouts/application.html.erb) and Tailwind source/output in [app/assets/tailwind/application.css](app/assets/tailwind/application.css) and [app/assets/builds/tailwind.css](app/assets/builds/tailwind.css).  
- Replace non-guaranteed Daisy-specific utility usage with Tailwind-native equivalents in teller views under [app/views/teller/dashboard](app/views/teller/dashboard).

2. Create transaction shell for split flows  
- Extract a reusable shell partial set in [app/views/teller/shared](app/views/teller/shared) for top context, page header/state/actions, reference panel, totals, cash impact, approval interrupt, receipt.  
- Preserve required zones and semantics from [docs/11_ui_ux_standards_concept.md](docs/11_ui_ux_standards_concept.md) and [docs/14_teller_ui_ux_standards_concept.md](docs/14_teller_ui_ux_standards_concept.md).

3. Add split transaction routes and controllers  
- Add Deposit/Withdrawal/Transfer page routes in [config/routes.rb](config/routes.rb).  
- Add page controllers/views in [app/controllers/teller](app/controllers/teller) and [app/views/teller](app/views/teller) while retaining existing validate/post/approval endpoints in [app/controllers/teller/transactions_controller.rb](app/controllers/teller/transactions_controller.rb), [app/controllers/teller/postings_controller.rb](app/controllers/teller/postings_controller.rb), and [app/controllers/teller/approvals_controller.rb](app/controllers/teller/approvals_controller.rb).

4. Refactor Stimulus by flow responsibility  
- Split [app/javascript/controllers/posting_form_controller.js](app/javascript/controllers/posting_form_controller.js) into focused controllers for line items, totals/gating, references, approval, and receipt.  
- Keep non-destructive state transitions and idempotent request behavior identical during migration.

5. Complete Phase 1A UX parity requirements  
- Ensure progressive disclosure patterns per flow (including deposit checks/holds, transfer counterparty, withdrawal-specific fields).  
- Implement deterministic validation messaging and blocked/approval-required distinctions across all split pages.  
- Add/refine account reference and account history UI using [app/controllers/teller/account_references_controller.rb](app/controllers/teller/account_references_controller.rb) and new teller account history endpoint/view as needed.

6. Accessibility and teller-ops hardening  
- Enforce keyboard order, focus behavior, readable numeric alignment, and aria-live/error semantics across split pages.  
- Add practical operator safeguards (loading/disabled states, duplicate-submit protection confirmation visuals).

7. Compatibility and migration closure  
- Keep [app/views/teller/dashboard/index.html.erb](app/views/teller/dashboard/index.html.erb) as transition entrypoint with links/redirects to split pages until full cutover.  
- Update tests to cover both backward compatibility and new flow surfaces in [test/controllers/teller](test/controllers/teller) and relevant system/integration tests.

8. Sprint closure artifacts  
- Add implemented-vs-deferred and risk log updates in [plan-bankCorePhase1A1BPrep.prompt.md](plan-bankCorePhase1A1BPrep.prompt.md).  
- Prepare next-queue items for Phase 1B flows from [docs/01_phase1_master_plan_concept.md](docs/01_phase1_master_plan_concept.md).

**Verification**
- RAILS_ENV=test bin/rails test test/controllers/teller/dashboard_controller_test.rb  
- RAILS_ENV=test bin/rails test test/controllers/teller/transactions_controller_test.rb test/controllers/teller/postings_controller_test.rb test/controllers/teller/approvals_controller_test.rb test/controllers/teller/account_references_controller_test.rb  
- RAILS_ENV=test bin/rails test  
- bin/rubocop  
- bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error  
- bin/bundler-audit  
- bin/importmap audit

**Decisions**
- DaisyUI path: Tailwind-only now, DaisyUI plugin deferred.  
- Flow shape: Split now into Deposit/Withdrawal/Transfer pages.  
- Scope: Complete remaining Phase 1A UI parity in this pass.
