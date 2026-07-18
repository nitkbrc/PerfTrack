# SCATS — Step-by-Step Build Plan for Cursor

Companion to `SCATS_PRD.md` and `SCATS_TRD.md`. Do these in order — each milestone is a sensible commit-sized chunk, and later prompts assume earlier ones are done.

**Before you start:** copy `SCATS_PRD.md` and `SCATS_TRD.md` into the repo (e.g. a `/docs` folder) and commit them first. Cursor reads repo files when you `@`-reference them in a prompt — having the source-of-truth docs actually in the project means every prompt below can point Cursor at the real spec instead of you re-explaining it each time.

Prompts are written to paste directly into Cursor's chat/composer. "Expected output" is what to check before moving to the next step — don't move on if it doesn't match.

---

## Phase 0 — Environment (terminal, not Cursor)

```bash
# Ruby via rbenv (WSL2/Ubuntu)
sudo apt update && sudo apt install -y rbenv
rbenv init   # follow its instructions to hook into your shell, then restart the shell
rbenv install -l | grep '^3\.4'   # pick the latest 3.4.x listed
rbenv install 3.4.<latest>
rbenv global 3.4.<latest>
ruby -v      # confirm

gem install rails -v 8.1.3
rails -v     # confirm
```

```bash
# Postgres via Docker Desktop — same pattern as AMS
mkdir scats && cd scats
cat > docker-compose.yml << 'YAML'
services:
  postgres:
    image: postgres:16
    environment:
      POSTGRES_USER: scats
      POSTGRES_PASSWORD: scats
      POSTGRES_DB: scats_development
    ports:
      - "5432:5432"
    volumes:
      - pg_data:/var/lib/postgresql/data
volumes:
  pg_data:
YAML
docker compose up -d
```

**Expected output:** `ruby -v` shows 3.4.x, `rails -v` shows 8.1.3, `docker ps` shows the postgres container running.

---

## Phase 1 — Scaffold the app (terminal)

```bash
rails new . -d postgresql --css=tailwind --skip-test --force
```

Edit `config/database.yml` so `development`/`test` point at `host: localhost`, `username: scats`, `password: scats`.

```bash
bin/rails db:create
git init && git add -A && git commit -m "Initial Rails scaffold"
```

Now open the folder in Cursor.

**Expected output:** `bin/rails server` boots, `localhost:3000` shows the default Rails welcome page, `git log` shows one commit.

---

## Milestone 1 — Devise auth

**Prompt:**
> Add Devise for authentication. Generate a `User` model with Devise's default modules (database_authenticatable, recoverable, rememberable, validatable) plus a `role` field as a string-backed Rails enum with values admin, faculty, student — see @SCATS_TRD.md section 4 and section 10 for the exact enum syntax. Run the migration. Restyle the Devise views (sign in, sign up, password reset) with Tailwind — don't leave them as unstyled default scaffolding. Add a role selector to the signup form for now; we'll lock signup down to admin-only once authorization is in place.

**Expected output:** `Gemfile` includes `devise`; migrations create `users` with `role`; `/users/sign_up` and `/users/sign_in` render styled forms and actually create a session; `rails db:migrate` runs clean.

---

## Milestone 2 — Core data model

**Prompt:**
> Using @SCATS_TRD.md section 4 as the exact spec, generate the remaining models and migrations: Department, Student, Division, SubDivision, Category, AchievementRequest, ReqHistory, ReasonTemplate. Match the columns and foreign keys exactly — `usn` on Student is a unique indexed string, not the primary key. Set up every association including the non-default foreign keys (Division.dean_user_id → User, SubDivision.supervisor_user_id → User, ReqHistory.actor_id → User). Add `status` on AchievementRequest and `div_type` on Division as string-backed enums. Do not create a Proof model — that's ActiveStorage, next step. Run migrations and show me the resulting schema.

**Expected output:** 8 new models + migrations; `db/schema.rb` shows all tables with correct FK columns and a unique index on `students.usn`; in `rails console`, `Division.new.dean` and `SubDivision.new.supervisor` resolve as `User` associations without errors.

---

## Milestone 3 — Proof uploads (ActiveStorage)

**Prompt:**
> Install ActiveStorage for local disk storage in development. Add the `active_storage_validations` gem. On AchievementRequest, add `has_many_attached :proofs` with validation that every file is `image/png` and under 5MB, and that at least one proof is present — see @SCATS_PRD.md section 9 and @SCATS_TRD.md section 4. Write a model spec (set up RSpec + FactoryBot first if not already present) confirming: a non-PNG file is rejected, a file over 5MB is rejected, and a request with zero files is invalid.

**Expected output:** ActiveStorage tables migrated; `config/storage.yml` has a working `local` service; `bundle exec rspec spec/models/achievement_request_spec.rb` passes all three cases.

---

## Milestone 4 — Core business rules

**Prompt:**
> Implement three rules from @SCATS_TRD.md section 6: (1) Dean/Supervisor mutual exclusivity — a Division validation rejecting a dean_user_id that already appears as any SubDivision's supervisor_user_id, and the mirror-image validation on SubDivision; (2) points snapshot — when an AchievementRequest's status changes to dean_approved, set points_awarded to category.points signed by the division's div_type, inside the same transaction as the status update; (3) Student#positive_total, Student#negative_total, Student#overall_score(k: 50) exactly as specified. Write model specs for all three, including a spec proving points_awarded doesn't change if category.points is edited after approval.

**Expected output:** assigning an already-supervisor user as a dean raises a validation error with a clear message (and vice versa); approving a request in a negative division sets a negative points_awarded; `overall_score` returns a float between 0 and 10 with net = 0 giving exactly 5.0; specs green.

---

## Milestone 5 — Authorization (Pundit)

**Prompt:**
> Add Pundit. Generate policies for AchievementRequest, Division, SubDivision, Category, Department, ReasonTemplate, User — based on @SCATS_TRD.md section 5. AchievementRequestPolicy needs `review?` (true if current_user supervises the request's category's sub_division) and `dean_decide?` (true if current_user deans that division). The other five are admin-only (`role == "admin"`). Add `after_action :verify_authorized` to ApplicationController so an unhandled action fails loudly instead of silently succeeding.

**Expected output:** a student hitting an admin-only controller action gets denied (403 or redirect with flash, your call); a faculty member who isn't the assigned supervisor can't call `review?`-gated actions on a request outside their sub-division.

---

## Milestone 6 — Admin CRUD

**Prompt:**
> Build CRUD controllers and Tailwind-styled views (index/new/edit, no destroy needed for most) under an `/admin` namespace for: Department, Division (including div_type and assigning a dean from existing faculty users), SubDivision (including assigning a supervisor), Category (including points), ReasonTemplate. Gate every action with the Pundit policies from the last step.

**Expected output:** `/admin/divisions` etc. all work for an admin, all reject non-admins; trying to assign a dean who's already a supervisor surfaces the Milestone 4 validation error in the form instead of a raw 500.

---

## Milestone 7 — Student submission (Path A)

**Prompt:**
> Build the student flow from @SCATS_PRD.md section 6, Path A: a form to create an AchievementRequest — cascading Division → SubDivision → Category select using Stimulus (no full page reload between steps), title, description, one or more PNG proof uploads. On create: status = submitted, and write the first ReqHistory row (action: "submit", actor: current student's user) in the same transaction as the request. Add a student dashboard showing overall_score prominently and a list of their own requests with current status.

**Expected output:** a student can submit end-to-end; `ReqHistory.first.action` for that request is `"submit"`; dashboard is scoped to `current_user` only, shows the right score.

---

## Milestone 8 — Supervisor flow (both paths)

**Prompt:**
> Build the supervisor flow from @SCATS_PRD.md section 6: a queue of `submitted` requests scoped to categories under the current supervisor's sub-division(s) (use the `review?` policy). Three actions: approve & forward (→ supervisor_approved), revert with a message (→ supervisor_reverted, logs ReqHistory with the comment), reject with a message (→ rejected, logs ReqHistory). The revert/reject form lets the supervisor pick a ReasonTemplate to pre-fill the comment box (still editable) or type freely — see @SCATS_TRD.md section 6 and PRD section 7. Also build Path B: a form for the supervisor to raise a request directly on behalf of a chosen student, in any category under their sub-division(s), creating the request already at supervisor_approved with the supervisor as actor.

**Expected output:** supervisor only sees requests in their own sub-division(s); all three actions transition status and log ReqHistory correctly; picking a reason template fills the textarea via Stimulus without wiping manual edits made after; a Path B request starts at supervisor_approved, skipping submitted entirely.

---

## Milestone 9 — Dean flow

**Prompt:**
> Build the dean flow: a queue of supervisor_approved requests scoped to the current dean's division (`dean_decide?` policy). Approve (→ dean_approved, triggers the Milestone 4 points snapshot and — once it exists — the notification job), revert for clarification (→ dean_reverted, comment), reject (→ rejected, comment). Reuse the reason-template pre-fill pattern from the supervisor flow.

**Expected output:** dean only sees requests forwarded within their own division; approve correctly sets points_awarded; a dean_reverted request reappears, actionable, in the originating supervisor's queue.

---

## Milestone 10 — Notifications

**Prompt:**
> Add a Notification model (recipient → User, message, read boolean default false, reference to the AchievementRequest). Create a Solid Queue job, enqueued whenever a request transitions to dean_approved, that creates a Notification for the student clearly stating positive or negative and the point amount. Add a bell-icon dropdown in the app layout as a Turbo Frame, showing unread notifications with a count badge, and a way to mark them read.

**Expected output:** approving a request as dean creates the correct Notification for the correct student; bell badge count updates without a full page reload; message text correctly says positive or negative.

---

## Milestone 11 — Test coverage pass

**Prompt:**
> Review coverage against @SCATS_TRD.md section 8 and fill gaps: request specs for each role's key actions (student submit; supervisor approve/revert/reject/initiate; dean approve/revert/reject), each confirming both the happy path and that Pundit blocks the wrong role. Add one Capybara system spec covering the full Path A lifecycle end to end: student submits → supervisor approves → dean approves → student sees updated score and a notification.

**Expected output:** `bundle exec rspec` green across model, request, and system specs; the system spec drives an actual browser session, not just controller calls.

---

## Milestone 12 — Seed data & polish

**Prompt:**
> Write db/seeds.rb: a few departments; 2–3 divisions (mix of positive and negative div_type) each with sub-divisions and categories with realistic point values; a handful of reason templates; one admin user; a couple of faculty users assigned as deans/supervisors; 5–10 students with a spread of achievement requests across different statuses. Then do a pass over flash messages and empty states (e.g. "no pending requests") across every major view.

**Expected output:** `rails db:seed` gives you a realistic-looking app on first run — no blank screens, a believable mix of pending/approved/rejected requests to click through.

---

Once Milestone 12 is done, you have a working local MVP matching the PRD end to end. Deployment (Kamal, per TRD §9) is a deliberately separate, later step — not part of this plan.
