# BankCORE

BankCORE is a Rails 8.1 core-banking foundation focused on teller operations, posting integrity, cash controls, and auditable transaction workflows.

## Current scope

Implemented (Phase 1 in progress):

- Teller context + teller session lifecycle (open/assign drawer/close)
- Transaction flows: deposit, withdrawal, transfer, check cashing
- Posting engine with balancing + idempotency by request id
- Supervisor approval interrupt and approval token validation for threshold-triggered transactions
- Receipt/audit views and audit event capture

Planned direction is in `docs/planned/` and `docs/considering/`. Implemented behavior is in `app/`, `config/`, and `db/`; see `docs/current/`.

## Tech stack

- Ruby on Rails 8.1
- MySQL (`mysql2`)
- Hotwire (Turbo + Stimulus) with importmap
- Tailwind CSS (`tailwindcss-rails`)
- Solid Queue, Solid Cache, Solid Cable
- Puma web server

## Prerequisites

- Ruby (version compatible with Rails 8.1)
- Bundler
- MySQL
- Node tooling is not required for importmap-based JS workflow

## Quick start

1) Install dependencies and prepare DB:

```bash
bin/setup
```

2) Start the app:

```bash
bin/dev
```

3) Open:

- `http://localhost:3000`
- Health endpoint: `GET /up`

## Local environment workflow

If you use `.env` for local DB credentials:

```bash
set -a
source .env
set +a
```

Use the local wrappers when needed:

```bash
bin/rails-local db:prepare
bin/dev-local
```

## Testing and quality checks

Run the local CI-equivalent bundle:

```bash
bin/ci
```

Or run checks individually:

```bash
bin/rubocop
bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error
bin/bundler-audit
bin/importmap audit
RAILS_ENV=test bin/rails db:test:prepare test
```

## Background jobs

- Dedicated worker entrypoint:

```bash
bin/jobs
```

- In single-server topology, Solid Queue can run in Puma when `SOLID_QUEUE_IN_PUMA` is set.

## Deployment

This project includes container + deploy scaffolding:

- `Dockerfile`
- `config/deploy.yml` (Kamal)
- `bin/docker-entrypoint`

## Documentation map

- Doc index: `docs/README.md`
- System charter: `docs/current/architecture/00_system_charter.md`
- Teller architecture: `docs/current/architecture/03_teller_architecture.md`
- Phase 1 specification: `docs/current/10_phase1_spec.md`
- Phase 1 implementation status: `docs/current/10_phase1_status.md`

## Contributing notes

- Prefer Rails-native primitives already in this codebase.
- Keep implemented-vs-planned language explicit in PRs.
- Preserve health check contract on `/up`.
- Use the contribution workflow in [CONTRIBUTING.md](CONTRIBUTING.md).

---

If you are onboarding this repo for the first time, start with `bin/setup`, then run `bin/ci` before opening a PR.
