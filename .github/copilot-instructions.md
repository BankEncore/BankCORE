# BankCORE Copilot Instructions

## Project snapshot
- Rails 8.1 monolith; current runtime code is mostly framework skeleton, while domain intent is documented in `docs/*_concept.md`.
- Primary stack: MySQL (`mysql2`), Hotwire (Turbo + Stimulus), importmap, Puma.
- Production durability uses Solid adapters (`solid_queue`, `solid_cache`, `solid_cable`) instead of in-memory defaults.

## Source-of-truth split (important)
- Treat `app/**`, `config/**`, `db/**`, and `.github/workflows/ci.yml` as implemented behavior.
- Treat `docs/00_system_charter_concept.md` and `docs/03_teller_focused_architecture_concept.md` as target architecture direction, not already-implemented modules.
- When adding domain code, align naming/boundaries with docs (Teller vs Posting vs Account vs Cash vs GL bridge), but do not claim features exist unless implemented.

## Roadmap assumptions vs current code
- `docs/01_phase1_master_plan_concept.md`, `docs/02_phase1_roadmape_concept.md`, and `docs/11-14*_concept.md` are design/implementation targets, not committed features.
- Docs reference Devise, Pundit, TailwindCSS, DaisyUI, and a teller route surface; these are not in the current Gemfile/routes yet.
- Keep proposals and PR descriptions explicit about status: “planned per docs” vs “implemented in this branch.”

## Critical workflows
- Bootstrap dev: `bin/setup` (idempotent; installs gems, `db:prepare`, clears logs/tmp; starts server unless `--skip-server`).
- Run app: `bin/dev` (currently `bin/rails server`).
- Local CI bundle: `bin/ci` (includes setup, lint, security scans, tests, and `RAILS_ENV=test db:seed:replant`).
- CI-parity test command: `RAILS_ENV=test bin/rails db:test:prepare test`.

## Required checks before handoff
- Style: `bin/rubocop`
- Security: `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error`, `bin/bundler-audit`, `bin/importmap audit`
- Ensure compatibility with CI jobs: `scan_ruby`, `scan_js`, `lint`, `test`, `system-test` in `.github/workflows/ci.yml`.

## Runtime boundaries and integration points
- Web entrypoint: `config/puma.rb`; optional in-process queue via `plugin :solid_queue` when `SOLID_QUEUE_IN_PUMA` is set.
- Worker entrypoint: `bin/jobs` (Solid Queue CLI) for dedicated job-processing topology.
- Health contract: keep `GET /up` in `config/routes.rb` operational for infra checks.
- Production DB is split by concern (`primary`, `cache`, `queue`, `cable`) in `config/database.yml`; preserve this separation when adding migrations/config.
- Container/deploy path is Kamal + Thruster (`Dockerfile`, `bin/docker-entrypoint`, `config/deploy.yml`).

## Project-specific conventions
- Prefer Rails-native primitives already present (Active Job + Solid Queue, Turbo, Stimulus) over introducing new frameworks.
- Stimulus convention: place controllers in `app/javascript/controllers/*_controller.js`; they are auto-loaded via `app/javascript/controllers/index.js` and `config/importmap.rb`.
- If implementing teller UX from conceptual docs, preserve the shell separation pattern (entry panel vs read-only reference panel vs totals/cash impact) while mapping to existing Hotwire/importmap setup.
- Use `config/recurring.yml` for scheduled job definitions (current example: hourly `SolidQueue::Job.clear_finished_in_batches`).
- In development, Action Cable uses `async` (`config/cable.yml`): manual cable-trigger debugging must happen from web console context, not a separate terminal `rails console`.

## Environment and secrets
- Never add hardcoded secrets; use credentials or environment variables.
- Keep DB config changes compatible with both local socket-based dev defaults and CI `DATABASE_URL` (`mysql2://127.0.0.1:3306`) flow.
