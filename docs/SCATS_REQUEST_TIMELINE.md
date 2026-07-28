# SCATS — Request Timeline & Versioning (new addition)

Fixes two related problems in one feature, not two separate ones:

1. **Reviewer queues only ever show pending items** — once a supervisor or dean acts on a request, it disappears from their view entirely, with no record of "you did this."
2. **Editing and resubmitting after a revert silently overwrites the old content** — no way for anyone to see what the original submission actually said.

The fix: `ReqHistory` starts recording *which version* of the request's content it applied to, not just the request as a whole. That single change solves both problems at once.

## Schema addition

**New model: `RequestVersion`**
- `id` (PK)
- `achievement_request_id` (FK, required)
- `version_number` (integer, starts at 1)
- `title`, `description`, `category_id` — snapshot copies
- `created_at`
- `has_many_attached :proofs` — moved here from `AchievementRequest`

**`ReqHistory` gains:** `request_version_id` (FK → `RequestVersion`, required)

**`AchievementRequest`** keeps its own `title`/`description` columns, kept in sync with whichever version is latest — so nothing else that already reads `request.title` directly needs to change.

## Behavior

- **Creating a request** (student submission or supervisor-initiated) creates the `AchievementRequest`, `RequestVersion` #1, and the first `ReqHistory` row together, one transaction.
- **Approve / revert / reject** — no new version; the `ReqHistory` row references whatever the *current* version is.
- **Student edits and resubmits** — creates a new `RequestVersion` (incremented number, new content + proofs), a `ReqHistory` row (action: `resubmit`) pointing at it, status back to `submitted`.

## Cursor prompts — do in order

**1. Migration + models**
> Create a `RequestVersion` model and migration: `achievement_request_id` (FK, required), `version_number` (integer, required), `title`, `description`, `category_id` (snapshot copies), timestamps. Move `has_many_attached :proofs` and its PNG/5MB validations from `AchievementRequest` to `RequestVersion`. Add `request_version_id` (FK → RequestVersion, required) to `req_histories`. `AchievementRequest has_many :request_versions`; add a `current_version` method returning the latest by `version_number`. `ReqHistory belongs_to :request_version`.

**Expected output:** migrations run clean; `achievement_request.current_version.proofs` resolves; existing proof-validation specs still pass against the new location.

**2. Update creation, revert, and resubmit logic**
> Update request creation (both student self-submission and supervisor-initiated) to create the AchievementRequest, its first RequestVersion (version_number 1, snapshotting submitted content and proofs), and the first ReqHistory row in one transaction. Update the student's edit-and-resubmit flow (available after status is `supervisor_reverted`) to create a new RequestVersion with the edited content/proofs, log a ReqHistory row (action: `resubmit`) referencing it, and set status back to `submitted`. Every other ReqHistory-writing action (approve, revert, reject) should reference the request's current version — no new version created there. Keep `AchievementRequest.title`/`description` mirroring whatever the latest version says.

**Expected output:** a fresh submission has exactly one RequestVersion; a revert-then-resubmit cycle produces two, both retrievable, with the request's own `title` matching version 2.

**3. Request timeline UI**
> On the AchievementRequest detail page (shared by student, supervisor, and dean), replace the current single-state view with a full timeline: every RequestVersion in order — content, proofs, submitted date — and nested under each, every ReqHistory entry that applied to it (actor, action, comment, timestamp). Same view for all three roles; no role-specific hiding of past versions.

**Expected output:** viewing a twice-reverted request as the student, the supervisor, or the dean all show the identical two-version history with the same review comments attached to the correct version.

**4. "Review history" for Supervisor and Dean**
> Add a Review History view for Supervisor and Dean — a separate nav item from their pending queue — listing every ReqHistory row where they're the actor: "You approved/reverted/rejected [request title] on [date]," each linking through to that request's full timeline from step 3.

**Expected output:** approving a request moves it out of the pending queue and into this history view instead of disappearing; clicking through shows the full timeline, not just the current state.
