# README

This README would normally document whatever steps are necessary to get the
application up and running.

Things you may want to cover:

* Ruby version

* System dependencies

* Configuration

* Database creation

* Database initialization

* How to run the test suite

* Services (job queues, cache servers, search engines, etc.)

* Deployment instructions

* ...

## Local DB setup

1. Copy `.env.example` to `.env` and set your local DB credentials.
2. Load env vars in your shell before Rails commands, for example:

```bash
set -a
source .env
set +a
```

3. Prepare the database:

```bash
bin/rails-local db:prepare
```

For any Rails command that needs local DB env vars, use:

```bash
bin/rails-local <task>
```

To run the development server with the same `.env` loading:

```bash
bin/dev-local
```
