## Plan: BankCORE Phase 1A with 1B Prep (DRAFT)

This plan converts the conceptual backlog into an executable sequence for the current Rails 8.1 skeleton, while keeping the implemented source of truth in app/config/db and treating docs as target direction. It prioritizes strong financial boundaries early (session guardrails before posting, posting invariants before teller transaction flows), preserves infrastructure contracts like [config/routes.rb](config/routes.rb) health checks, and stages UI behavior to match teller UX standards without overbuilding. Based on your scope choice, this delivers a full Deposit vertical slice and prepares shared primitives needed for Withdrawal/Transfer/Approval flows in the next increment.

**Steps**
1. Baseline and governance lock
   - Confirm architecture contracts from [docs/00_system_charter_concept.md](docs/00_system_charter_concept.md), [docs/03_teller_focused_architecture_concept.md](docs/03_teller_focused_architecture_concept.md), and UX constraints from [docs/11_ui_ux_standards_concept.md](docs/11_ui_ux_standards_concept.md), [docs/14_teller_ui_ux_standards_concept.md](docs/14_teller_ui_ux_standards_concept.md).
   - Preserve health endpoint in [config/routes.rb](config/routes.rb) and CI contract in [/.github/workflows/ci.yml](.github/workflows/ci.yml).

2. Sprint 0 foundation (Auth, context, UI shell)
   - Establish Rails native authentication as the baseline using `bin/rails g authentication` (not Devise), then add policy foundation and role scaffolding in [Gemfile](Gemfile), [config/routes.rb](config/routes.rb), [app/controllers/application_controller.rb](app/controllers/application_controller.rb), and new policy/auth files under [app](app).
   - Introduce request context primitives (branch, workstation, current teller session) in [app/models](app/models) and controller concerns under [app/controllers/concerns](app/controllers/concerns).
   - Build teller shell structure in [app/views/layouts/application.html.erb](app/views/layouts/application.html.erb) and minimal stimulus hooks in [app/javascript/controllers](app/javascript/controllers).
   - Clean secret handling and DB config assumptions in [config/database.yml](config/database.yml) and seed baseline roles in [db/seeds.rb](db/seeds.rb).

3. Sprint 1 teller session and cash control
   - Add domain models/migrations for TellerSession, CashLocation, CashLocationAssignment, and AuditEvent in [db](db) and [app/models](app/models).
   - Implement open/assign/close session workflows through teller namespace routes/controllers/views in [config/routes.rb](config/routes.rb), [app/controllers](app/controllers), [app/views](app/views).
   - Enforce hard guard: no financial posting action without open session and drawer assignment.
   - Persist auditable session lifecycle events (open, assign, close attempt, close complete).

4. Sprint 2 posting backbone and invariants
   - Add immutable posting artifacts (TellerTransaction, PostingBatch, PostingLeg, CashMovement, AccountTransaction) via migrations and models in [db](db), [app/models](app/models).
   - Create Posting engine service pipeline in new [app/services](app/services) with stages: request build, validation, policy check, leg generation, balance check, atomic commit.
   - Add idempotency key handling and uniqueness constraints at DB and service levels.
   - Add preparatory extension points for 1B (approval hook interface, transaction type adapters for withdrawal/transfer).

5. Sprint 3 deposit vertical slice (E2E)
   - Build deposit entry UI with dynamic check line items and live totals using [app/views](app/views) plus Stimulus controllers in [app/javascript/controllers](app/javascript/controllers).
   - Add validate endpoint for authoritative server-side recomputation and rule feedback.
   - Add post endpoint that commits only through Posting engine.
   - Add receipt/confirmation view tied to persisted posting identifiers.
   - Add approval interrupt seam (trigger + resume contract) as 1B prep, without full approval UX expansion.

6. Test and quality gates per sprint
   - Add targeted model/service/controller/integration tests under [test](test), including invariants (balanced entries, immutability, idempotency, session guard).
   - Run quality/security gates each sprint and full CI parity at sprint close.

7. Handoff criteria and backlog transition
   - Publish sprint-end artifacts: implemented scope, deferred items, risk log, and ready queue for Withdrawal/Transfer implementation using prepared adapters.
   - Keep “planned vs implemented” explicitly separated in status notes per repo guidance.

**Verification**
- Setup and environment: bin/setup --skip-server
- Style: bin/rubocop
- Security: bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error
- Dependency audit: bin/bundler-audit
- JS import audit: bin/importmap audit
- Test parity: RAILS_ENV=test bin/rails db:test:prepare test
- System tests: RAILS_ENV=test bin/rails db:test:prepare test:system
- Full local CI bundle: bin/ci

**Decisions**
- Scope decision: Phase 1A delivery with 1B preparation (not full 1B delivery).
- Authentication decision: standardize on Rails native authentication (`bin/rails g authentication`) for Sprint 0; treat Devise references in conceptual docs as planned direction superseded for this implementation track.
- Architectural decision: enforce Posting as the only financial commit authority; Teller orchestrates but does not directly mutate ledger artifacts.
- UX decision: implement non-destructive teller flow and live totals now; defer expanded approval UX and full transaction family rollout to next phase using prepared seams.
- Delivery decision: strict sprint gates aligned to [/.github/workflows/ci.yml](.github/workflows/ci.yml) and project scripts.
