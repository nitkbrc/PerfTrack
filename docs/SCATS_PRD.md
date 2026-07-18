# Student Character and Achievement Tracking System (SCATS)
### Product Requirements Document — Revised

---

## 1. Purpose

To provide a structured platform where students submit achievements (or have them submitted on their behalf by a supervisor) with proof, a two-stage review process verifies them, and verified achievements contribute signed points to a student's character record — positive for genuine achievements, negative for conduct issues — visible separately to the student and to staff.

Beyond point-tracking, the system exists to give faculty a reliable, persistent record of student character over time. A student's academic and extracurricular excellence is usually well documented and remembered, but conduct issues often aren't — they get raised informally, handled verbally, and forgotten as people move on. Left untracked, that creates real institutional risk: when the college later vouches for a student — a recommendation letter, a placement referral, an internal nomination — staff may unknowingly stake the college's reputation on an incomplete picture of that student's record. SCATS exists to close that gap, treating positive and negative history with the same rigor so neither gets lost to memory or staff turnover.

## 2. Goals

- Enable students to submit achievement requests digitally, and allow supervisors to raise requests on a student's behalf (required for conduct issues, optional elsewhere).
- Provide a two-level verification workflow: Supervisor → Dean, with a terminal Rejected outcome — reachable at either stage — for invalid or fraudulent claims.
- Attach a fixed point value to every achievement category, and a polarity (positive/negative) to every division, so verified requests translate into signed points automatically.
- Allow administrators to dynamically manage users, divisions, sub-divisions, categories, category point values, departments, and predefined revert/reject reasons.
- Maintain a transparent, append-only history of every request's lifecycle for auditability.
- Notify students when points are added to their record, with positive and negative additions shown separately.

## 3. User Roles

The `Users.role` field is one of: **Admin, Faculty, Student**. **Dean** and **Supervisor** are not separate role values — they are capacities a Faculty member holds by being assigned to a Division (Dean) or to one or more Sub-divisions (Supervisor).

These two capacities are mutually exclusive per person, and Dean is additionally capped at one division:

- A **Dean** is dean of exactly one division, and cannot simultaneously hold a Supervisor assignment anywhere.
- A **Supervisor** may supervise multiple sub-divisions at once, but cannot simultaneously be a Dean of any division.

This rule spans two tables (`Divisions.dean_user_id` and `Sub_divisions.supervisor_user_id`), so it can't be enforced by a plain foreign key — see the Data Model notes (§7) for how to validate it.

| Role | Permissions |
|---|---|
| **Admin** | Create, edit, and remove Users (including designating or un-designating a Faculty member as Dean or Supervisor, subject to the exclusivity rule above). Create, edit, and delete Divisions (including polarity), Sub-divisions, Categories (including point values), Departments, and predefined reason templates. Assign a Dean to a Division and a Supervisor to one or more Sub-divisions. Cannot view or edit any student's achievement data. |
| **Faculty** | Read-only visibility into every student's overall score in bulk/list views; selecting an individual student reveals their positive total, negative total, and full request history. Cannot edit anything. |
| **Dean** *(Faculty assigned to a Division)* | Everything Faculty can do, plus: final reviewer for every request forwarded by a supervisor in their division. May **approve** (points awarded to the student), **revert** to the supervisor for clarification, or **reject** (terminal, no points, message required). |
| **Supervisor** *(Faculty assigned to one or more Sub-divisions)* | Everything Faculty can do, plus: review requests submitted under any category in their sub-division(s) — **approve & forward** to the relevant Dean, **revert** to the student with a message, or **reject** outright (terminal, no points, message required) for clearly invalid submissions. May also directly raise a request on behalf of any student in their sub-division(s) (see §6). |
| **Student** | Submit achievement requests with proof, in any category. View only their own overall score, positive total, negative total, and full request history with status. Receive a notification whenever a request affecting them reaches Dean-approved, labeled as a positive or negative point addition. |

## 4. System Hierarchy

**Division → Sub-division → Category**

- **Division** — broad area (e.g. Sports, Academics, Cultural Activities, Discipline). Carries a **polarity**: `positive` or `negative`. A Dean is assigned per division.
- **Sub-division** — organizational grouping under a division (e.g. International, National, State). A Supervisor is assigned per sub-division, covering every category beneath it. One supervisor may cover several sub-divisions.
- **Category** — the specific, point-bearing unit (e.g. "National Championship Winner," "Unauthorized Absence"). Carries a fixed **point value**.

## 5. Points & Polarity System

- **`Categories.points`** — a fixed, positive magnitude set by Admin (e.g. `20`). Same value for every student who earns that category.
- **`Divisions.div_type`** — `positive` or `negative`, set by Admin at creation. This is what makes a "Negative division" for conduct issues: the sign lives at the division level and cascades down, so a category itself never stores a negative number.
- **`Achievement_Requests.points_awarded`** — a signed integer, **null until Dean-approved**, then snapshotted as `category.points × (+1 if division is positive, -1 if negative)`. Snapshotting (rather than joining live) means a later edit to a category's point value never retroactively changes an already-verified student's history.
- **Positive/negative totals are computed, not stored.** No running-total columns on Students. Positive total = `SUM(points_awarded)` for that student's Dean-approved requests where the division is positive; negative total = the same, filtered to negative divisions.
- **Overall score (out of 10), for bulk/list views.** Showing separate positive and negative totals for every row in a class roster or bulk list is noisy — so bulk views show a single overall score out of 10, and reserve the positive/negative breakdown for the individual student's detail view.

  Suggested formula (tunable):
  ```
  net = positive_total - |negative_total|
  overall_score = 10 / (1 + e^(-net / k))
  ```
  `k` is an admin-configurable scale constant. A student with `net = 0` (no history, or exactly balanced) scores a neutral 5/10, not a 0. Because this is a sigmoid, the score stays bounded between 0 and 10 no matter how large point totals get — it doesn't need recalibrating every time a high-value category is added. Start with a default like `k = 50` and tune once there's real point data to look at; this constant is not something to lock in before the system has usage.

  Like the positive/negative totals, `overall_score` is computed on demand, not cached — if bulk list performance becomes a problem at scale, add a short-TTL cache at the API layer rather than a stored column, so it can never drift from the underlying requests.

## 6. Request Lifecycle

Two ways a request can start; both converge into the same review process.

**Path A — Student self-submission**
Student picks a category, fills in details, uploads proof → status `Submitted`.

**Path B — Supervisor-initiated**
Supervisor selects a student and raises the request directly in any category under one of their sub-divisions, for either a positive or negative division → status starts at `Supervisor Approved` (the supervisor creating it *is* the review step, so it skips `Submitted`). The first history entry records the supervisor, not the student, as the originator.

| From | Action | To |
|---|---|---|
| `Submitted` | Supervisor approves | `Supervisor Approved` |
| `Submitted` | Supervisor reverts (message) | `Supervisor Reverted` |
| `Submitted` | Supervisor rejects (message) | `Rejected` *(terminal — no points)* |
| `Supervisor Reverted` | Student edits & resubmits | `Submitted` |
| `Supervisor Approved` | Dean approves | `Dean Approved` *(terminal — points snapshotted)* |
| `Supervisor Approved` | Dean requests clarification | `Dean Reverted` |
| `Supervisor Approved` | Dean rejects (message) | `Rejected` *(terminal — no points)* |
| `Dean Reverted` | Supervisor clarifies & re-forwards | `Supervisor Approved` |

Every transition — including the initial `Submitted` (or supervisor-initiated) event — is written to `Req_history` (action, from_status, to_status, comment, actor, timestamp, and optionally a reason template — see §7). This is what satisfies auditability and what the "list of achievements and bad deeds" UI is built from.

## 7. Data Model

| Entity | Key attributes |
|---|---|
| **Users** | user_id (PK), name, email, password_hash, role |
| **Departments** | department_id (PK), department_name |
| **Students** | usn (PK), user_id (FK → Users, required), department_id (FK → Departments, required), name, section |
| **Divisions** | division_id (PK), division_name, div_type, dean_user_id (FK → Users, required, unique) |
| **Sub_divisions** | subdivision_id (PK), division_id (FK → Divisions, required), subdivision_name, supervisor_user_id (FK → Users, required) |
| **Categories** | category_id (PK), subdivision_id (FK → Sub_divisions, required), category_name, points |
| **Achievement_Requests** | request_id (PK), student_usn (FK → Students, required), category_id (FK → Categories, required), title, description, status, submitted_at, points_awarded (nullable until Dean-approved) |
| **Proof** | proof_id (PK), request_id (FK → Achievement_Requests, required), file_name, file_path, uploaded_at |
| **Req_history** | history_id (PK), request_id (FK → Achievement_Requests, required), actor_user_id (FK → Users, required), reason_id (FK → Reason_Templates, nullable), action, from_status, to_status, comment, created_at |
| **Reason_Templates** | reason_id (PK), message_text |

**Constraints derived from the ER diagram's participation lines:**
- NOT NULL: `Students.user_id`, `Students.department_id`, `Divisions.dean_user_id`, `Sub_divisions.division_id`, `Sub_divisions.supervisor_user_id`, `Categories.subdivision_id`, `Achievement_Requests.student_usn`, `Achievement_Requests.category_id`, `Proof.request_id`, `Req_history.request_id`, `Req_history.actor_user_id`.
- `Req_history.reason_id` is nullable — most actions (e.g. an approval) have no associated reason template.
- `Divisions.dean_user_id` carries a UNIQUE constraint — one user can be dean of at most one division. `Sub_divisions.supervisor_user_id` does not — one supervisor can cover several sub-divisions.
- **Dean/Supervisor exclusivity (§3) spans two tables and can't be a plain constraint.** Validate at the application layer whenever either assignment is made: reject assigning someone as dean if their user_id already appears in any `Sub_divisions.supervisor_user_id`, and vice versa.
- **`Achievement_Requests` requires at least one `Proof` row.** A bare FK can't force a "must have at least one child" rule — enforce by inserting the request and its first proof file in the same transaction.
- **`Achievement_Requests` and `Req_history` are mutually required (§6).** Create the request row and its first `Req_history` row (the submit or supervisor-initiate event) in the same transaction, so neither can exist without the other.
- **Predefined reasons:** selecting a `Reason_Templates` entry pre-fills `Req_history.comment` with its `message_text`; the supervisor/dean can still edit the text before saving. `reason_id` just records which template (if any) the final comment started from — `comment` is always the actual text shown to the student.

## 8. Notifications

Student receives a notification the moment a request reaches `Dean Approved`, clearly labeled as a positive or negative point addition, naming the category and point value.

## 9. Non-Functional Requirements

- **Security:** role-based access control, encrypted password storage.
- **Auditability:** every status change logged in `Req_history` — no destructive updates to request status without a corresponding history row.
- **File handling:** proof uploads are PNG only; multiple PNGs may be attached to a single request; 5MB maximum per file. Validate both file extension and actual MIME type server-side, not filename alone.
- **Usability:** responsive interface across student, supervisor, and dean views.
- **Scalability:** dynamic addition of divisions, sub-divisions, categories, departments, and users without schema changes.

## 10. Future Scope

- **Parent role:** view-only access to a linked student's score and history. Not designed further in this document — treat as its own scoped addition when prioritized, rather than assumed anywhere above.

## 11. Success Criteria

- Students can submit achievement requests with proof; supervisors can raise requests directly on a student's behalf.
- Supervisors can review, forward, revert, or reject requests in their sub-division(s); deans can review, approve, revert, or reject requests forwarded to them.
- Points are awarded automatically and correctly signed on Dean approval, and never retroactively change.
- A student can see their overall score plus the full positive/negative breakdown behind it at any time; staff see overall score in bulk views and the full breakdown on an individual student.
- Every status change, including the initial submission or supervisor-initiation event, is traceable to an actor and a timestamp.
