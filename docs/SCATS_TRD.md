# Student Character and Achievement Tracking System (SCATS)
### Technical Requirements Document

Companion to `SCATS_PRD.md`. This document translates that PRD into a concrete Ruby on Rails implementation.

---

## 1. Architecture

**Traditional Rails monolith** — server-rendered views (ERB) with Hotwire (Turbo + Stimulus) for interactivity, not a separate frontend framework. This follows directly from choosing Devise: session-cookie auth works cleanly within a same-origin Rails app, and avoids the cross-origin/token complexity a decoupled API + SPA would reintroduce — which is exactly what you were avoiding by skipping JWT.

```
Browser (Turbo Drive/Frames + Stimulus)
        │
Rails app (MVC, Devise, Pundit)
        │
PostgreSQL  +  ActiveStorage (local disk in dev → S3-compatible in prod)
        │
Solid Queue (background jobs, DB-backed — no Redis)
```

## 2. Tech Stack

| Layer | Choice | Notes |
|---|---|---|
| Language | Ruby 3.4.x, YJIT enabled | Ruby 4.0 exists but its JIT (ZJIT) is still experimental; 3.4 + YJIT is the current production-recommended combination. |
| Framework | Rails 8.1.x | Latest stable as of mid-2026. |
| Database | PostgreSQL 16+ | Same as AMS — via Docker Desktop locally. |
| Auth | Devise 5.x | Confirmed Rails 8 compatible. |
| Authorization | Pundit | Policy objects for "can this user act on this request" checks. |
| Frontend | Turbo + Stimulus (bundled with Rails) + Tailwind CSS | `rails new --css=tailwind`. No separate JS framework. |
| File uploads | ActiveStorage + `active_storage_validations` gem | Declarative PNG/5MB validation. |
| Background jobs | Solid Queue (bundled with Rails 8) | No Redis needed. |
| Testing | RSpec + FactoryBot + Faker | Model specs, request specs, a handful of system specs for the core workflow. |

## 3. Local Development Environment

Matches your existing Docker Desktop + WSL2 setup from AMS, with one change: Ruby/Rails runs **natively** (via `rbenv` or `asdf`), not inside a container — only Postgres lives in Docker. This keeps the dev loop fast (no container rebuild for every code change) while still using Docker Desktop the way you already do.

```yaml
# docker-compose.yml
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
```

**Prisma Studio's replacement:** `rails console` for querying/mutating data via ActiveRecord, `bin/rails db` to drop into `psql` directly, or a GUI tool (TablePlus / DBeaver / pgAdmin) pointed at `localhost:5432` for a Prisma-Studio-like table browser.

## 4. Data Model (ActiveRecord)

| Model | Table | Key columns |
|---|---|---|
| `User` | users | id (PK), name, email, encrypted_password (Devise), role (enum: admin/faculty/student) |
| `Department` | departments | id (PK), name |
| `Student` | students | id (PK), usn (unique, indexed, NOT NULL), user_id (FK, NOT NULL), department_id (FK, NOT NULL), section |
| `Division` | divisions | id (PK), name, div_type (enum: positive/negative), dean_user_id (FK → users, NOT NULL, **unique**) |
| `SubDivision` | sub_divisions | id (PK), division_id (FK, NOT NULL), name, supervisor_user_id (FK → users, NOT NULL) |
| `Category` | categories | id (PK), sub_division_id (FK, NOT NULL), name, points (integer) |
| `AchievementRequest` | achievement_requests | id (PK), student_id (FK, NOT NULL), category_id (FK, NOT NULL), title, description, status (enum), points_awarded (nullable integer) |
| `ReqHistory` | req_histories | id (PK), achievement_request_id (FK, NOT NULL), actor_id (FK → users, NOT NULL), reason_template_id (FK, nullable), action, from_status, to_status, comment |
| `ReasonTemplate` | reason_templates | id (PK), message_text |

Proof files: `AchievementRequest has_many_attached :proofs` (ActiveStorage) — no separate table.

**Associations sketch:**
```ruby
class User < ApplicationRecord
  devise :database_authenticatable, :recoverable, :rememberable, :validatable
  enum :role, { admin: "admin", faculty: "faculty", student: "student" }

  has_one  :student_profile, class_name: "Student"
  has_many :deaned_divisions, class_name: "Division", foreign_key: :dean_user_id
  has_many :supervised_sub_divisions, class_name: "SubDivision", foreign_key: :supervisor_user_id
  has_many :req_histories, foreign_key: :actor_id
end

class AchievementRequest < ApplicationRecord
  belongs_to :student
  belongs_to :category
  has_many :req_histories
  has_many_attached :proofs

  enum :status, { submitted: "submitted", supervisor_approved: "supervisor_approved",
                   supervisor_reverted: "supervisor_reverted", dean_approved: "dean_approved",
                   dean_reverted: "dean_reverted", rejected: "rejected" }

  validates :proofs, presence: true
  validates :proofs, content_type: ["image/png"], size: { less_than: 5.megabytes }
end
```

**Dean/Supervisor mutual exclusivity — application-level validation, not a DB constraint** (it spans two tables):

```ruby
class Division < ApplicationRecord
  belongs_to :dean, class_name: "User", foreign_key: :dean_user_id
  validate :dean_is_not_a_supervisor

  private
  def dean_is_not_a_supervisor
    if SubDivision.exists?(supervisor_user_id: dean_user_id)
      errors.add(:dean_user_id, "is already a supervisor elsewhere")
    end
  end
end
# SubDivision gets the mirror-image validation against Division.dean_user_id.
```

## 5. Authorization (Pundit)

One policy per resource, checked against the capacity relationships rather than a role string:

```ruby
class AchievementRequestPolicy < ApplicationPolicy
  def review?
    user.faculty? && record.category.sub_division.supervisor_user_id == user.id
  end

  def dean_decide?
    user.faculty? && record.category.sub_division.division.dean_user_id == user.id
  end
end
```

Admin/Faculty/Student base permissions are straightforward `role == "admin"` etc. checks; Dean/Supervisor-specific actions always check the actual FK relationship, never a role value — there isn't one.

## 6. Business Logic Notes

- **Points snapshot** happens in the same transaction as the Dean-approve status transition, not via a callback triggered by something else — this keeps the "why did points change" trail entirely inside `Req_history`.
- **Positive/negative totals and overall score are plain query methods on `Student`**, not stored columns — computed on every read, per the PRD.
- **Overall score formula** (§5 of the PRD): a sigmoid mapping net points to 0–10, implemented as a plain Ruby method:
  ```ruby
  def overall_score(k: 50)
    net = positive_total - negative_total.abs
    (10 / (1 + Math.exp(-net.to_f / k))).round(1)
  end
  ```
- **Supervisor-initiated requests** create the `AchievementRequest` and its first `Req_history` row in the same transaction, with `status: :supervisor_approved` from the start and `actor` set to the supervisor, not the student.

## 7. Notifications

Solid Queue job enqueued when a request transitions to `dean_approved`. For the MVP, "notification" means a row in a lightweight `notifications` table (recipient, message, read boolean, created_at) surfaced as a bell-icon dropdown via Turbo Frames — no email/push infrastructure needed yet. This can be swapped for ActionMailer or a push service later without touching the rest of the app.

## 8. Testing Strategy

- **Model specs:** validations (exclusivity rule, PNG/size constraints), enum transitions, association integrity.
- **Request specs:** one per role's key action (student submits, supervisor approves/reverts/rejects, dean approves/reverts/rejects) — verifying both the happy path and that Pundit actually blocks the wrong role.
- **System specs (Capybara):** the full Path A lifecycle (submit → supervisor approve → dean approve → points visible) and Path B (supervisor-initiated → dean approve).

## 9. Deployment (deferred)

Not building this yet, per your call to reach a reasonable stage first — but worth knowing now: **Rails 8 ships with Kamal**, a deployment tool built for exactly this — Docker-based deploys to any VPS, which lines up with the Docker Desktop experience you already have. When you're ready, this is the natural next step rather than reaching for Vercel-style platforms that don't fit a Rails monolith as cleanly.

## 10. Confirmed Defaults

1. **Ruby version manager:** `rbenv`.
2. **Enum backing values:** strings, not integers — `enum :status, { submitted: "submitted", supervisor_approved: "supervisor_approved", ... }`. Costs nothing and reads correctly in `psql`/DBeaver without a lookup table in your head.
