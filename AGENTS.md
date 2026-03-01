# Agent Guide for BankCORE

This file defines how coding agents should operate in this repository.
It applies to the entire repo unless a deeper-level `AGENTS.md` overrides it.

## Project context

BankCORE is a Rails 8.1 core-banking foundation focused on:

- teller session lifecycle
- deposit/withdrawal/transfer/check-cashing flows
- balanced and idempotent posting
- supervisor approval interrupts and token validation
- receipt/audit capture

## Source-of-truth rules

- Implemented behavior in `app/`, `config/`, and `db/` is authoritative.
- `docs/*_concept.md` files describe target direction unless implemented code differs.
- Keep implemented-vs-planned wording explicit in changes and summaries.

## Architecture and coding preferences

- Prefer Rails-native primitives already used in this codebase.
- Keep changes small, focused, and directly related to the request.
- Avoid unrelated refactors while completing feature or bug-fix work.
- Preserve the health check contract at `GET /up`.

## Safety-critical expectations

For any changes touching money movement, approvals, or audits:

- Preserve posting balance guarantees.
- Preserve idempotency semantics for request IDs.
- Do not bypass supervisor approval controls.
- Do not weaken audit event coverage or traceability.

## Setup and local workflow

Primary setup and run commands:

```bash
bin/setup
bin/dev
```

If using `.env` credentials locally:

```bash
set -a
source .env
set +a
bin/rails-local db:prepare
bin/dev-local
```

## Required quality checks

Run the full local CI bundle when possible:

```bash
bin/ci
```

Equivalent individual checks:

```bash
bin/rubocop
bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error
bin/bundler-audit
bin/importmap audit
RAILS_ENV=test bin/rails db:test:prepare test
```

## Testing guidance for agents

- Add or update tests for any material behavior change.
- Prefer focused tests near changed code, then run broader checks as needed.
- Do not claim completion without running at least relevant checks or explaining why not run.

## Documentation guidance

- Update docs when behavior changes materially.
- Keep terminology aligned with teller/posting/audit domain language in existing docs.

## Security and secrets

- Never commit credentials, tokens, or private keys.
- Use environment variables or Rails credentials for secret material.

## Commit guidance

- Use clear, imperative commit messages (for example: `Fix drawer prerequisite for transfer posting`).
- Group related edits in a single commit when possible.
