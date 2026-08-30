# SCATS

**Student Character and Achievement Tracking System**

SCATS is a Rails application for institutes to record verified student achievements and conduct outcomes as a durable character ledger. Students (or authorised faculty on their behalf) submit requests with proof; configurable review chains verify them; approved outcomes contribute signed points to each student’s record — positive for achievements, negative for conduct. The student and faculty UIs show this as a 0–10 **SCATS Score**.

> Active development. Schema, permissions, and UI may still evolve.

---

## Features

- **Path A** — student submits a request with proof  
- **Path B** — eligible faculty raise a request on a student’s behalf  
- **Configurable review chains** — shared hierarchy templates (division / sub-division) with ordered review roles; staffing via role assignments  
- **Multi-step advance / revert / reject** — live chain resolution; unstaffed roles are skipped  
- **Hierarchy change safety** — in-flight requests are remapped onto the new staffed chain when templates change or owners are reattached (with history + notifications)  
- **SCATS Score** — 0–10 sigmoid of net approved points (`k` is admin-tunable); points are snapshotted at final approval  
- **Integrity Index** — student dashboard donut of achievement vs conduct points; 0/0 and “No data” when nothing is approved yet  
- **Admin console** — users (CSV import), departments, divisions / sub-divisions / categories (archive), review roles, role assignments, hierarchy templates, reason templates, settings  
- **Role permissions** — profile self-edit toggles; per review-role permission to create/import students  
- **Faculty student create / CSV import** — gated by review-role flags and live assignments  
- **Notifications & email** — in-app student notifications on approval; Action Mailer for review events (works in development with `.env`; production SMTP is not wired yet)  
- **Unsaved-changes guard** — leave confirm (Stay / Discard / Save & exit) on save surfaces  

---

## Tech stack

| Layer | Choice |
| --- | --- |
| Framework | Ruby on Rails ~> 8.1 |
| Language | Ruby 3.4.8 (see `.ruby-version`) |
| Database | PostgreSQL 16 |
| Auth | Devise (no self-registration; admin-provisioned accounts) |
| Authorization | Pundit |
| Frontend | Hotwire (Turbo + Stimulus), Tailwind CSS, Importmap |
| Jobs / cache | Solid Queue, Solid Cache (primary DB) |
| Uploads | Active Storage |
| Deploy | Docker + Render blueprint (`render.yaml`) |
| Tests | RSpec, Capybara |

---

## Roles and review model

`User.role` is one of **`admin`**, **`faculty`**, or **`student`**.

**Dean**, **Supervisor**, and other titles are **`ReviewRole`s**, not separate user roles. Faculty hold them through **`RoleAssignment`s** on a division or sub-division. Chains are defined by **hierarchy templates** attached to those owners.

| Actor | Capabilities |
| --- | --- |
| **Admin** | Org structure, users/imports, review roles, hierarchies, assignments, reason templates, score scale, role permissions. Does not browse student character scores. |
| **Faculty** | Student directory and SCATS Score breakdowns; review queues when assigned; optional student create/import when their review role allows it. |
| **Student** | Submit / resubmit requests; view own SCATS Score, Integrity Index, timeline, and notifications. |

Default seeded Technical / Coding demo chain:

`Supervisor → Coordinator → Division Reviewer → Dean`

Final points are recorded only when the last staffed step approves.

---

## Prerequisites

- Ruby **3.4.8** (rbenv or equivalent)  
- Bundler  
- Docker Desktop (Postgres 16 via Compose)  
- Node is **not** required for day-to-day JS (Importmap); Tailwind is built via `tailwindcss-rails`  

On Windows, development is typically done in **WSL2** with Docker Desktop integration.

---

## Local setup

```bash
git clone <your-fork-or-remote> scats
cd scats

bundle install

# Start PostgreSQL (user/password/db: scats / scats / scats_development)
docker compose up -d

bin/rails db:prepare   # create + migrate
bin/rails db:seed      # idempotent demo data

bin/rails server
```

Open [http://localhost:3000](http://localhost:3000).

### Demo logins (from seeds)

Printed again at the end of `db:seed`. Defaults:

| Role | Email | Password |
| --- | --- | --- |
| Admin | `admin@scats.edu` | `admin123` |
| Faculty / others | e.g. `meera.nair@scats.edu`, `kavya.shetty@scats.edu`, `asha.kumar@scats.edu` | `password123` |

`db:seed` is safe to re-run; it does not duplicate structure or re-create requests for students who already have them.

### Tailwind

After changing Tailwind sources:

```bash
bin/rails tailwindcss:build
```

### Stop local Postgres

```bash
docker compose stop
```

---

## Configuration

### Environment

Copy [`.env.example`](.env.example) to `.env` for optional local mail (never commit `.env`):

```bash
cp .env.example .env
```

| Variable | Purpose |
| --- | --- |
| `GMAIL_USERNAME` / `GMAIL_APP_PASSWORD` | Development SMTP only (`config/environments/development.rb`). Production mail is not configured. |
| `DATABASE_URL` | Production / Render Postgres URL |
| `RAILS_MASTER_KEY` | Decrypt `config/credentials` (required in production / Docker) |
| `RAILS_ENV` | `development` locally; `production` on Render |
| `SOLID_QUEUE_IN_PUMA` | Run Solid Queue inside Puma (set on Render) |

Development uses Compose Postgres (`config/database.yml`). Production uses a single `DATABASE_URL` for app, queue, and cache tables.

### Credentials

Production needs `RAILS_MASTER_KEY` matching `config/master.key` (or the credentials key used to build the image). Do not commit secrets.

---

## Tests

```bash
bundle exec rspec
```

Focused examples:

```bash
bundle exec rspec spec/services/hierarchy_bulk_save_spec.rb
bundle exec rspec spec/services/in_flight_request_remapper_spec.rb
bundle exec rspec spec/requests/faculty/student_create_spec.rb
```

---

## Deployment (Render)

Blueprint: [`render.yaml`](render.yaml) — Docker web service + Postgres (`scats` / `scats-db`), typically from the `nitkbrc/PerfTrack` remote.

1. Connect the GitHub repo in Render (Blueprint or existing service).  
2. Set **`RAILS_MASTER_KEY`**.  
3. Deploy; run migrations against production if the release process does not already:

   ```bash
   RAILS_ENV=production DATABASE_URL='postgresql://…?sslmode=require' bin/rails db:migrate
   ```

4. Optional: `bin/rails db:seed` only for demo environments (avoid on real production data).

**Notes that matter in practice**

- Free Render web and Postgres sleep when idle and are region-limited; first requests and cross-region latency can feel slow. That is hosting capacity, not missing app bootstrapping.
- Uploads use Active Storage **disk** (`config.active_storage.service = :local`). Redeploys can drop profile photos and proof files even though the database rows remain. Object storage (S3) is not configured.
- Review emails will **not** leave Render until production SMTP and the matching env vars are added. In-app notifications still work.

Health check: `GET /up`.

---

## Repository layout (high level)

```text
app/
  controllers/     # admin, students, supervisors, deans, faculties, …
  models/          # User, AchievementRequest, Hierarchy, ReviewRole, …
  services/        # ReviewChainResolver, HierarchyBulkSave, InFlightRequestRemapper, …
  javascript/      # Stimulus controllers (hierarchies, leave-guard, …)
  views/
config/
db/migrate/ db/seeds.rb
spec/
render.yaml        # Render blueprint
docker-compose.yml # Local Postgres 16
Dockerfile         # Production image
```

---

## Remotes

This codebase is often pushed to both:

- Application fork / working remote (e.g. `origin`)  
- Institute remote (e.g. `brcSir` → `nitkbrc/PerfTrack`)

Keep `main` in sync on both when releasing.

---

## License / ownership

Internal institute project unless otherwise stated by the maintainers. Ask before redistributing.
