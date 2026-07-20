# SCATS

**Student Character and Achievement Tracking System**

A structured platform where students submit achievements (or have them submitted on their behalf by a supervisor) with proof, a two-stage review process verifies them, and verified achievements contribute signed points to a student's character record — positive for genuine achievements, negative for conduct issues — visible separately to the student and to staff. Beyond point-tracking, SCATS gives faculty a reliable, persistent record of student character so neither excellence nor conduct issues are lost to memory or staff turnover.

> This project is under active development. APIs, schema, and UI may change.

---

## Tech stack

| Layer | Choice |
|---|---|
| Framework | Ruby on Rails 8.1 |
| Language | Ruby 3.4.8 |
| Database | PostgreSQL 16 |
| Auth | Devise |
| Authorization | Pundit |
| Frontend | Hotwire (Turbo + Stimulus), Tailwind CSS |
| File uploads | Active Storage |
| Tests | RSpec, Capybara |

---

## Run locally

**Prerequisites:** Ruby 3.4.8, Docker Desktop, Bundler.

```bash
# 1. Install gems
bundle install

# 2. Start Postgres
docker compose up -d

# 3. Set up the database
bin/rails db:create db:migrate db:seed

# 4. Start the server
bin/rails server
```

Open [http://localhost:3000](http://localhost:3000).

`db:seed` loads demo departments, divisions, users, and sample requests. Seeded logins are printed at the end of the seed run (default passwords: `password123`, admin: `admin123`).

After CSS changes, rebuild styles if needed:

```bash
bin/rails tailwindcss:build
```

Stop Postgres when done: `docker compose stop`.

---

## Roles

`Users.role` is one of **Admin**, **Faculty**, or **Student**.

**Dean** and **Supervisor** are not separate roles — they are capacities a Faculty member holds by assignment:

- **Dean** — assigned to exactly one Division; cannot also be a Supervisor.
- **Supervisor** — assigned to one or more Sub-divisions; cannot also be a Dean.

| Role / capacity | What they do |
|---|---|
| **Admin** | Manage users, departments, divisions, sub-divisions, categories, and reason templates. Cannot view student achievement data. |
| **Faculty** | Browse all students' overall scores; open a student for positive/negative breakdown and contributing requests. |
| **Dean** *(Faculty)* | Final review: approve (award points), revert to supervisor, or reject. |
| **Supervisor** *(Faculty)* | First review: approve & forward, revert to student, or reject. Can also raise requests on a student's behalf. |
| **Student** | Submit requests with proof; see own score, history, and approval notifications. |

Review flow: **Student / Supervisor → Supervisor → Dean**. Points are snapshotted only on dean approval.
