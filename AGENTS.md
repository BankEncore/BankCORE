# AGENTS.md

## Cursor Cloud specific instructions

### Services overview

BankCORE is a Rails 8.1 monolith (Ruby 3.4.1, MySQL, Hotwire/Tailwind CSS). Standard commands are in `README.md` and `CONTRIBUTING.md`.

### MySQL startup

MySQL must be started before any Rails command. Run:

```
sudo mysqld --user=mysql --datadir=/var/lib/mysql --socket=/var/run/mysqld/mysqld.sock --pid-file=/var/run/mysqld/mysqld.pid &
sleep 3
sudo chmod 755 /var/run/mysqld/
```

The app connects via the `DB_USERNAME` / `DB_PASSWORD` / `DB_HOST` / `DB_PORT` env vars (injected as secrets). If the MySQL user doesn't exist yet, create it:

```
mysql -u root -e "CREATE USER IF NOT EXISTS '${DB_USERNAME}'@'localhost' IDENTIFIED BY '${DB_PASSWORD}'; GRANT ALL PRIVILEGES ON *.* TO '${DB_USERNAME}'@'localhost' WITH GRANT OPTION; CREATE USER IF NOT EXISTS '${DB_USERNAME}'@'127.0.0.1' IDENTIFIED BY '${DB_PASSWORD}'; GRANT ALL PRIVILEGES ON *.* TO '${DB_USERNAME}'@'127.0.0.1' WITH GRANT OPTION; FLUSH PRIVILEGES;"
```

### Database migration gotcha (MySQL 8.0)

MySQL 8.0 does not support bare `DEFAULT CURRENT_DATE` in CREATE TABLE. The `accounts` table migration (`20260223000004_create_accounts.rb`) uses `default: -> { "CURRENT_DATE" }` which fails on MySQL 8.0. Workaround: manually create the accounts table with `DEFAULT (CURRENT_DATE)` (parenthesized), mark the migration as done, then run remaining migrations. See the migration file for the full column list.

The database default collation must be `utf8mb4_general_ci` (not `utf8mb4_0900_ai_ci`). Create databases with: `CREATE DATABASE bank_core_development CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;`

### Active Record Encryption

Seeding and running the app with Party data requires AR encryption keys. Set these env vars (generate new ones with `bin/rails db:encryption:init`):

- `ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY`
- `ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY`
- `ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT`

These are persisted in `~/.bashrc` on this VM.

### Running the dev server

The `bin/dev` command uses Foreman to run Puma + Tailwind CSS watcher. The Tailwind watcher (`tailwindcss:watch`) may exit immediately on some environments; if so, build CSS once with `bin/rails tailwindcss:build` and run the server directly with `bin/rails server -b 0.0.0.0 -p 3000`.

### Lint / test / build commands

See `README.md` and `CONTRIBUTING.md`. Key commands:

- `bin/rubocop` — style checks
- `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error` — security analysis
- `bin/bundler-audit` — gem vulnerability audit
- `bin/importmap audit` — JS dependency audit
- `RAILS_ENV=test bin/rails test` — run test suite
- `bin/ci` — all checks combined

### Seeded test users

| Email | Role | Password | Branch |
|---|---|---|---|
| teller@bankcore.local | Teller | ChangeMe123! | Main Branch (001) |
| supervisor@bankcore.local | Supervisor | ChangeMe123! | Main Branch (001) |
| admin@bankcore.local | Admin | ChangeMe123! | (all) |
| csr@bankcore.local | CSR | ChangeMe123! | Main Branch (001) |
| operations@bankcore.local | Admin | ChangeMe123! | (all) |

The teller user is only authorized for **Main Branch** — selecting other branches will cause Pundit authorization errors.
