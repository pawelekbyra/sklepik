# Render deployment readiness

## Status

This is a documentation-only audit for deploying the `pawelekbyra/sklepik` backend on Render.

Current status: **not directly Render-ready as a root-level Ruby/Rails service**.

The repository root is a Spree workspace / monorepo-style project with Node, pnpm, Turbo, Spree packages, and helper scripts for creating and running a Rails backend in `server/`. The root is not itself a committed Rails application.

No production deployment was attempted as part of this audit. No secrets, API keys, `master.key`, production data, cart logic, checkout logic, Store API changes, or Spree core changes were added.

## Obecny błąd Render

Render failed with:

```text
Running build command 'bundle install'...
Could not locate Gemfile
Build failed
```

This happened because Render ran `bundle install` in the repository root. The repository root does **not** contain a `Gemfile`, so Bundler cannot treat the root as a Rails app.

This is a deployment-configuration / repository-shape issue, not evidence that Spree itself cannot run on Render.

## Struktura repo

Audited files:

| Path | Status | Finding |
| --- | --- | --- |
| `package.json` | present | Root package is named `spree`; it uses pnpm, Turbo, and contains `server:*` helper scripts. |
| `pnpm-lock.yaml` | present | Root lockfile exists and contains workspace importers, including `packages/*`. |
| `turbo.json` | present | Root tasks are Turbo tasks for build/test/lint/typecheck, not Rails tasks. |
| `README.md` | present | Upstream Spree README-style content describes Spree as a headless eCommerce platform. |
| `AGENTS.md` | present | Local project rules define this repo as the backend for Kakaowy Sklepik and Spree as the commerce source of truth. |
| `docs/deployment-map.md` | absent | No deployment map document exists at the time of this audit. |
| `scripts/server-setup.sh` | present | Creates `server/` from `spree-starter`, writes `server/.env`, builds CLI, and starts the edge dev stack. |
| `scripts/server-build.sh` | present | Rebuilds the edge dev Docker images; it assumes `server/Gemfile.lock` exists. |
| `scripts/docker-compose.edge.yml` | present | Development overlay for running `web` and `worker` against the local Spree monorepo. |
| `docker-compose.yml` | absent at root | No root compose file was found. |
| `Dockerfile` | absent at root | No root production Dockerfile was found. |
| `Gemfile` | absent at root | Root is not a direct Rails app. |
| `server/Gemfile` | absent in repo | `server/` is not committed in this repository. |
| `server/Dockerfile` | absent in repo | `server/` is not committed in this repository. |
| `server/Procfile` | absent in repo | `server/` is not committed in this repository. |
| `server/bin/rails` | absent in repo | `server/` is not committed in this repository. |
| `server/config/database.yml` | absent in repo | `server/` is not committed in this repository. |
| `server/config/storage.yml` | absent in repo | `server/` is not committed in this repository. |
| `server/.env.example` | absent in repo | `server/` is not committed in this repository. |

## Czy root repo jest deployowalne?

No, not as a direct Render Ruby/Rails app.

Confirmed facts:

- The root has `package.json`, not a `Gemfile`.
- The root `package.json` defines pnpm/Turbo scripts and helper scripts such as `server:create`, `server:setup`, `server:dev`, `server:build`, `server:seed`, and `server:load_sample_data`.
- The `server:create` script clones `https://github.com/spree/spree-starter.git` into `server/`, removes that clone's Git metadata, and writes `server/.env`.
- The root `server:dev` script expects `server/docker-compose.dev.yml` to exist, then layers `scripts/docker-compose.edge.yml` on top of it.
- No root `Gemfile`, root `Dockerfile`, or root `docker-compose.yml` exists.

Conclusion: the root repo is best understood as a Spree source/workspace plus project wrapper and tooling. It is not currently a directly deployable Rails application root.

## Katalog server

`server/` does **not** exist as a committed directory in this repository at the time of the audit.

The intended local flow is:

```bash
pnpm run server:create
```

or the more complete:

```bash
pnpm run server:setup
```

Those scripts create `server/` from `spree-starter` and then run the local development stack.

Important distinction:

- `server/` is currently generated local state.
- `server/` is not currently a committed application artifact.
- Render cannot set `Root Directory = server` unless `server/` is committed in the Git repository being deployed.

Can Render generate `server/` in the build step? Technically, a build command could run `pnpm install`, `pnpm run server:create`, then `cd server && bundle install ...`. However, this is not recommended as the stable deployment shape because every deploy would depend on cloning the latest `spree-starter` during build, which is not pinned by this repo and can drift over time.

Recommended deployment readiness decision: create and commit a real Rails/Spree application artifact instead of generating it during Render builds. The cleanest approach is a separate backend app repository, for example `pawelekbyra/KakaowySklepikBackend`, based on `spree-starter` and configured for Kakaowy Sklepik. An alternative is to commit a production-ready `server/` directory in this repo and use Render's monorepo Root Directory setting, but that is a larger repository-shape decision.

## Rekomendowany wariant deployu

Recommended for the next deployment attempt: **Render Ruby runtime, but only after there is a committed Rails app root**.

Preferred target shape:

```text
Render Web Service -> committed Rails/Spree app root with Gemfile
```

That app root can be either:

1. a separate backend Rails app repository generated from `spree-starter`, or
2. a committed `server/` directory inside this repo, with Render Root Directory set to `server`.

Do **not** point Render Ruby runtime at the current repository root.

Docker runtime is a valid future option if the committed Rails app includes a production Dockerfile and the team wants stronger parity with containerized local development. It is not the recommended immediate fix because the current repo has no root Dockerfile and no committed `server/Dockerfile` to deploy.

The existing `scripts/docker-compose.edge.yml` is a local development overlay. It mounts the local monorepo into containers and runs `web` and `worker`. It should not be treated as a production Render Docker configuration without additional work.

## Render Web Service

For a committed Rails/Spree app root, the expected Render Web Service shape is:

```text
Runtime: Ruby
Root Directory: app root that contains Gemfile
Build Command: app-specific build script or bundle/assets command
Pre-deploy Command: db migrations, if available on the selected Render plan
Start Command: Rails server bound to Render's PORT
```

If `server/` is committed in this repo, then Render can use:

```text
Root Directory: server
```

If the backend is split into a separate repository, Root Directory should be unset or set to the directory that contains the Rails app's `Gemfile`.

## Render Postgres

Spree/Rails should use a persistent database. Render Postgres is sufficient for test/MVP exploration.

Expected env var:

```text
DATABASE_URL=<Render internal database URL>
```

The generated Rails app's `config/database.yml` could not be audited because `server/` is not committed. In a normal Rails-on-Render setup, `DATABASE_URL` is the preferred production configuration and usually avoids hardcoding production database credentials in `config/database.yml`.

Do not use SQLite for production or semi-production Render deployments. Render service filesystems are ephemeral, and local database files can be lost on redeploy/restart/spin-down.

Extensions: no specific Postgres extensions were confirmed from this repository because the Rails app and migrations are not committed here. Re-check after the actual backend app exists.

## Render Redis / worker

The local development stack explicitly models two services:

```text
web
worker
```

The worker command in the local Docker overlay ends with:

```bash
bundle exec sidekiq
```

That indicates the production deployment should plan for a background worker service, not only a web service.

Recommended Render shape once the Rails app is committed:

```text
Web Service: Rails web process
Background Worker: bundle exec sidekiq
Key Value / Redis-compatible service: backing store for Sidekiq if the app uses Sidekiq in production
```

Expected env var depends on the generated app's configuration. Common names include:

```text
REDIS_URL=<Render Key Value internal URL>
```

Do not assume the exact variable name until the committed Rails app and Sidekiq configuration are audited.

Render Key Value can be used for testing, but free Key Value instances are in-memory only and can lose state when restarted. That is acceptable for readiness testing, not for reliable production job queues.

## Env vars

Confirmed / expected production env vars for a committed Rails/Spree app:

```text
RAILS_ENV=production
RACK_ENV=production
DATABASE_URL=<Render Postgres internal URL>
RAILS_MASTER_KEY=<contents of config/master.key, set only in Render secrets>
SECRET_KEY_BASE=<secure generated value, set only in Render secrets if required by the app>
WEB_CONCURRENCY=2
REDIS_URL=<Render Key Value / Redis URL, if Sidekiq is enabled>
RAILS_SERVE_STATIC_FILES=true
RAILS_LOG_TO_STDOUT=true
```

Project-specific env vars still need confirmation after the real Rails app root exists:

```text
SPREE_* settings
SMTP/email settings
payment provider settings
Active Storage S3/R2 settings
canonical host / CORS settings for the frontend
```

Do not commit any real values. Do not commit `master.key`.

## Build command

Because the current repo root is not a Rails app, this command is **invalid at root**:

```bash
bundle install
```

For a committed Rails/Spree app root, the recommended command should be based on that app's actual files. A typical starting point is:

```bash
bundle install && bundle exec rails assets:precompile
```

A more Render-friendly production shape is to add an app-local script in the committed Rails app, for example:

```bash
bin/render-build.sh
```

and use that as Render's Build Command.

Do not use the following as the long-term production build command unless the team explicitly accepts the drift risk:

```bash
pnpm install --frozen-lockfile && pnpm run server:create && cd server && bundle install && bundle exec rails assets:precompile
```

That command would generate the Rails app during deploy by cloning `spree-starter`, which is not pinned by the current repo state.

## Start command

For a committed Rails/Spree app root, the expected start command is:

```bash
bundle exec rails server -b 0.0.0.0 -p $PORT
```

or, if the committed app has `bin/rails`:

```bash
bin/rails server -b 0.0.0.0 -p $PORT
```

This cannot be applied to the current repository root because the root does not contain Rails boot files.

## Pre-deploy migrations

For a committed Rails/Spree app root, Render should run migrations before promoting a new deploy:

```bash
bundle exec rails db:migrate
```

or:

```bash
bin/rails db:migrate
```

Render pre-deploy commands may require a paid instance type. If testing on a free web service, migration logic might temporarily live in the build script, but that should be treated as a test-only compromise and documented in the PR/deploy notes.

Do not run production migrations from this audit branch.

## Assets

Rails/Spree assets should be precompiled for production as part of the build:

```bash
bundle exec rails assets:precompile
```

The local development overlay also runs:

```bash
bin/rails spree:admin:tailwindcss:build
```

That suggests the Spree Admin asset build may matter for production as well, but the exact production build command must be confirmed against the committed Rails app generated from `spree-starter`.

## Storage / media

Do not rely on local filesystem storage for product media on Render.

Render service filesystems are ephemeral. Uploaded images and generated local files can be lost across redeploys, restarts, or free-plan spin-downs.

Recommended target decision:

```text
Active Storage -> S3-compatible object storage
```

Cloudflare R2 is a good candidate for Kakaowy Sklepik media, but this audit does not configure it. The future backend app should document the required env vars for S3/R2, for example bucket, endpoint, access key, secret key, and region/compatibility settings.

## Admin setup

Admin belongs to the backend / Spree Admin, not to `KakaowySklepikFront`.

This repo already documents that the first admin user should be created by the backend Spree mechanism, a seed/setup task, or manually in a secure admin environment. It also states that production logins, passwords, tokens, API keys, and private admin addresses must not be committed.

Confirmed root scripts relevant to initialization:

```bash
pnpm run server:seed
pnpm run server:load_sample_data
```

These run inside `server/` after it exists:

```bash
cd server && spree rails db:seed
cd server && spree task load_sample_data
```

Because `server/` is not committed, the exact production admin creation command is not confirmed in this repo. After generating/committing the real Rails app, audit its Spree tasks and seed files before documenting a production-safe admin setup command.

## Publishable key

The frontend expects:

```text
SPREE_API_URL=<backend URL>
SPREE_PUBLISHABLE_KEY=<publishable Store API key, if required>
```

The current backend repo does not contain a committed Rails app or seed data, so this audit cannot confirm an existing publishable key.

Expected process after backend app exists:

1. boot the Rails/Spree backend in a secure environment,
2. create or find the relevant Store / Sales Channel / publishable API key through Spree Admin or documented Spree task,
3. copy only the public/publishable key to the frontend deployment env var `SPREE_PUBLISHABLE_KEY`,
4. keep admin tokens and secrets out of the frontend and out of Git.

Whether public product listing requires `X-Spree-Api-Key` must be confirmed against the actual Spree version/configuration and the generated backend app. The current frontend adapter already supports sending `X-Spree-Api-Key` when `SPREE_PUBLISHABLE_KEY` is set.

## Free plan vs production

The current Render free plan is acceptable for discovery and smoke testing only.

Known constraints that matter for this project:

- Free web services spin down after inactivity, causing cold starts.
- Free web services have ephemeral local filesystems.
- Free Postgres is limited and expires after a fixed trial period.
- Free Key Value is in-memory only and can lose queued/background state on restart.
- Free services are not suitable for a production commerce backend.

Use free Render resources to validate deployment shape, boot, migrations, admin access, Store API reachability, and frontend integration. Move to paid services before real customers, orders, payments, or production media uploads.

## Czego nie robić

Do not:

- point Render Ruby runtime at the current repository root and run `bundle install`,
- commit secrets, tokens, API keys, passwords, `config/master.key`, or production data,
- generate `server/` during every Render deploy as a long-term workaround,
- mutate Spree core only to make Render build pass,
- move backend commerce logic into the frontend,
- implement cart, checkout, payment, or Store API changes in this documentation PR,
- rely on Render local filesystem for product images,
- treat free Render services as production-ready for a real shop.

## Następny krok

Recommended next step:

1. Generate a real Rails/Spree backend app from `spree-starter` in a controlled local environment.
2. Decide repository shape:
   - preferred: create a separate committed backend app repo, or
   - alternative: commit `server/` as the app root and configure Render Root Directory to `server`.
3. Add production-safe Render build/start/migration documentation based on the actual committed app files.
4. Create Render Web Service + Render Postgres + Render Key Value / worker services for a smoke test.
5. After backend boot is confirmed, expose the backend URL to `KakaowySklepikFront` as `SPREE_API_URL` and add the publishable key if required.

Until step 2 is complete, the correct answer to the failed deploy is: **Render was pointed at the wrong app root. The current repo root is not a Rails app and has no Gemfile.**
