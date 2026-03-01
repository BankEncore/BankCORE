# Contributing to BankCORE

## Ground rules

- Treat implemented behavior in `app/`, `config/`, and `db/` as source of truth.
- Treat `docs/considering/` and `docs/planned/` as target/planned direction; `docs/current/` as implemented spec.
- Keep PRs small and focused; avoid unrelated refactors.

## Branch & PR flow

1. Create a branch from `main`:

   ```bash
   git checkout -b feat/<short-name>
   ```

2. Make changes with tests.
3. Run checks locally (see below).
4. Open a PR using the PR template.

## Local checks (required)

```bash
bin/rubocop
bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error
bin/bundler-audit
bin/importmap audit
RAILS_ENV=test bin/rails db:test:prepare test
```

You can also run:

```bash
bin/ci
```

## Commit style

Use clear, imperative commit messages, for example:

- `Add approval policy-trigger metadata to audit events`
- `Fix drawer prerequisite for transfer posting`

## Documentation expectations

- Update docs when behavior changes materially.
- Be explicit whether a change is implemented now or planned per docs.

## Security & secrets

- Never commit credentials or secrets.
- Use environment variables or Rails credentials.

## Need help?

Open a GitHub issue using the provided templates.
