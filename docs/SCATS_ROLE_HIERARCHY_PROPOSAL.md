# SCATS — Full Build Plan: Permissions, Reorg, and the Role Hierarchy Engine

Final — supersedes the earlier draft of this file. Everything below reflects confirmed answers, not open questions.

Deployed on Render. Phase A is three small, independent fixes — do them in any order, today. Phase B is one continuous, sequenced rebuild of the review workflow — don't interleave it with unrelated work, and don't skip the "additive first, cutover later" ordering given production traffic depends on the old columns until Step B4.

---

## Phase A — independent, do first

### A1. Scoring aggregation bug (urgent — live data integrity)

`dean_approve!` itself is correct — `points_awarded` is computed once, signed, and frozen at approval. The bug is downstream, wherever `positive_total`/`negative_total` currently get computed — if that query re-joins back to `category.sub_division.division.div_type` instead of trusting the sign already stored on `points_awarded`, a later polarity change silently reshuffles old, already-decided scores.

**Prompt:**
> Find wherever `positive_total`/`negative_total` (or equivalent student score aggregation) is currently computed. Fix it so it sums `points_awarded` by its own stored sign only — `SUM(points_awarded) WHERE points_awarded > 0` for positive, `WHERE points_awarded < 0` for negative — with no join back to `categories`, `sub_divisions`, or `divisions` in that calculation. Add a regression spec: approve a request under a positive division, then change that division's `div_type` to negative, then assert the student's positive total is unchanged. That's the exact bug this fixes.

### A2. Profile field editability

Reuses the `Permission` table below — this is the concrete first use of it, not a separate system.

**Prompt:**
> Add a `Permission` model/table: `role` (string), `action` (string key), `enabled` (boolean). Seed rows for `edit_own_phone`, `edit_own_address`, `edit_own_photo`, each for student and faculty — admin is never gated by these. Defaults: student → phone/address disabled, photo enabled; faculty → all three enabled. On the profile/settings page, each field's presence in the edit form (not just the update action) should check `Permission.enabled_for?(current_user.role, "edit_own_#{field}")` — disabled renders as read-only display, not a hidden-but-submittable input. Reject the param server-side too regardless of what the form sent. Build an admin settings page listing every `Permission` row as a toggle matrix, grouped by action — this becomes the general home for every togglable permission in the app going forward, not just these three.

### A3. Archive cascades to auto-reject pending requests

`Category#archive!` (and its cascade from `SubDivision#archive!`/`Division#archive!`) currently only sets `archived_at` — nothing touches the requests sitting inside. Build against the **current** status model now; Phase B will touch this method again once the status model itself changes, but the behavior stays the same.

**Prompt:**
> In `Category#archive!`, after setting `archived_at`, find every `AchievementRequest` in this category still in a non-terminal status (`submitted`, `supervisor_approved`, `supervisor_reverted`, `dean_reverted`) and transition each to `rejected`, with `comment: "Automatically rejected — category archived"`, actor set to whoever is performing the archive (the admin), action `"auto_reject_archived"`. Add a case for `"auto_reject_archived"` in `enqueue_transition_mail!` that calls `enqueue_final_decision_mails!(:rejected_notification, actor: actor, comment: comment)` — same notification behavior as a normal reject, regardless of which stage the request was at when the category was archived. `dean_approved`/`rejected` requests are untouched either way — they're historical fact. Since `SubDivision#archive!` and `Division#archive!` already cascade down to `Category#archive!`, this one change covers archiving at any level.

---

## Phase B — the role hierarchy engine

One continuous rebuild. Do these in order; each step depends on the last actually working, not just being written.

### B1. Additive schema (safe to deploy standalone — nothing reads from these tables yet)

**Prompt:**
> Create three models/migrations:
> - `ReviewRole`: `name` (string), `scope` (enum: `division`/`sub_division`), `raiseable_on_behalf_eligible` (boolean — only meaningful for `sub_division` scope), `system_role` (boolean). Seed system roles: **only** Dean (`scope: division`) and Supervisor (`scope: sub_division`, raiseable-eligible). Associate Dean is **not** a system role — if present it is a normal custom/deletable role like any other mid step (e.g. “Division Reviewer”). System roles can't be deleted by admin; everything else can. Each division/sub-division needs at least one same-scope step — not necessarily Dean/Supervisor. If Supervisor is present it stays first in that sub-division chain; if Dean is present it stays last in that division chain.
> - `HierarchyStep`: `review_role_id` (FK), `division_id` (nullable FK), `sub_division_id` (nullable FK — exactly one of division_id/sub_division_id set, matching the review role's scope), `position` (integer), `can_raise_on_behalf` (boolean, only settable when the step's role has `raiseable_on_behalf_eligible: true`). Each division and each sub-division has its own independent ordered list — no shared template between sub-divisions under the same division.
> - `RoleAssignment`: `user_id` (FK), `review_role_id` (FK), `division_id` (nullable), `sub_division_id` (nullable — same exactly-one-set pattern).
>
> Don't touch `divisions.dean_user_id`, `sub_divisions.supervisor_user_id`, or any existing controller/model logic yet — this step only adds tables.

### B2. Data migration — backfill from existing columns

**Prompt:**
> Write a data migration: for every existing `Division`, create a `HierarchyStep` (Dean role, position 1) and a `RoleAssignment` from its current `dean_user_id`. For every existing `SubDivision`, create a `HierarchyStep` (Supervisor role, position 1, `can_raise_on_behalf: true`) and a `RoleAssignment` from its current `supervisor_user_id`. After this runs, the new tables exactly mirror current production state — but nothing user-facing changes yet, the app still reads the old columns.

**Expected output:** in Rails console on the actual production data (or a copy of it), every division/sub-division has exactly one corresponding `RoleAssignment`, matching `dean_user_id`/`supervisor_user_id` 1:1.

### B3. The resolver — build and verify in isolation before touching the live state machine

**Prompt:**
> Build a resolver, either as methods on `AchievementRequest` or a dedicated service object: `review_chain` returns the ordered list of `[review_role, assigned_user]` pairs for this specific request — walk the sub-division's `HierarchyStep`s in order, then the division's, looking up the live `RoleAssignment` for each and skipping any step with none. `current_reviewer` returns whoever holds the step the request is currently at. `next_step` and `previous_step` navigate the *currently resolved* chain — critically, always computed fresh against live `HierarchyStep`/`RoleAssignment` data, never cached on the request itself, so a hierarchy edit made after a request started moving is automatically reflected the next time the chain is resolved. Write specs against this in isolation, covering: a step with no assignment gets skipped, a person holding the same role across multiple sub-divisions resolves correctly for each, and a hierarchy edited mid-flight changes what `next_step`/`previous_step` return without anything on the request itself changing.

**Do not proceed to B4 until these specs are solid.** This is the part that has to be correct before anything depends on it.

### B4. Cut the state machine over

The biggest step. `AchievementRequest`'s fixed `status` enum and the `dean_approve!`/`transition!` methods are built for exactly two stages — they need replacing with logic that works against a chain of arbitrary length.

**Prompt:**
> Replace `AchievementRequest`'s status enum with three broad states: `in_review`, `reverted`, and two terminals `approved`/`rejected`. Add `current_step_id` (FK → HierarchyStep) tracking exactly where in the resolved chain the request sits. Rewrite the transition methods using B3's resolver:
> - `advance!(actor:, comment: nil)` — if `next_step` exists, move `current_step_id` there, log history (action `"advance"`); if there's no next step (current step is the chain's last), this is final approval — snapshot `points_awarded` exactly as `dean_approve!` does today (`category.points * (division.positive? ? 1 : -1)`), set status `approved`, fire `approved_notification` per the existing Path A/B recipient logic.
> - `revert!(actor:, comment:)` — move to `previous_step`. If there is no previous step (current step is the chain's first), this reverts to whoever created the request (student for Path A, the specific staff member for Path B) — same floor rule as today's `supervisor_revert`. Set status `reverted`.
> - `reject!(actor:, comment:)` — callable from any step, terminal, same `rejected_notification` recipient logic as today (student always; originating supervisor too if Path B).
>
> Update Pundit policies: authorization for review actions checks "is `current_user` the `RoleAssignment` holder for this request's `current_step`" — not any hardcoded dean/supervisor check. Update `student_initiated?`/`originating_supervisor` — logic unchanged, they already correctly read the first `ReqHistory` row regardless of chain length.

**Expected output:** the full lifecycle — submit, advance through an arbitrary-length chain, revert exactly one step, reject from any point — works end to end against a seeded division with a 4+ step hierarchy, not just the old 2-step case.

### B5. Update queues and views

**Prompt:**
> Replace every controller query currently filtering by the old fixed status values (e.g. "requests where status is submitted and I'm the sub-division's supervisor") with a query against B4's resolver: "requests where I am the `current_reviewer`." For anyone holding the same role across multiple sub-divisions, add a filter/tab to view each assigned sub-division's queue separately, not just one merged list.

### B6. Admin UI for the hierarchy engine

**Prompt:**
> Build admin screens for: creating/renaming/deleting custom `ReviewRole`s (scope division or sub_division); configuring a division's or sub-division's `HierarchyStep` order (add/remove/reorder role steps); assigning `RoleAssignment`s (pick a user for a role at a specific division/sub-division, respecting the exclusivity rules below — surface violations as a clear form error, not a raw database exception); toggling `can_raise_on_behalf` per eligible step; and a bulk-apply action — select several sub-divisions (or several divisions) and apply one hierarchy configuration to all of them as independent copies, not a shared reference.
>
> Exclusivity validations (application-layer, same pattern as the existing Dean/Supervisor rule, generalized):
> - A person holding any `division`-scoped role cannot hold any other role anywhere — no other division-scoped role, no sub-division-scoped role, and not the same role for a second division.
> - A person holding a `sub_division`-scoped role can hold that *same* role type across other sub-divisions, but never a different role type anywhere else, division- or sub-division-scoped.

### B7. Drop the old columns — separate, later deploy, only after B4–B6 are confirmed working in production

**Prompt:**
> Remove `divisions.dean_user_id` and `sub_divisions.supervisor_user_id`, and any remaining code paths that reference them directly instead of going through `RoleAssignment`.

Don't bundle this with B4's deploy. Keep a rollback path available until the new resolver has actually handled real production traffic without issues.