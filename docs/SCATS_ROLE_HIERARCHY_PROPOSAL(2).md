# SCATS — Full Build Plan: Permissions, Reorg, and the Role Hierarchy Engine

Final — supersedes all earlier drafts. Reflects the **shared-template** model with locked product decisions below. Phase B is one continuous sequenced rebuild — don't interleave with unrelated work.

---

## Locked product decisions

- **Templates are shared:** `Hierarchy` + `HierarchyRole`; owners point via `hierarchy_id`.
- **UI orientation:** final reviewer at **top**, initial at **bottom** in both flowchart and drag list; DB `position` stays review order (`1` = first/initial … `N` = final); UI renders reversed.
- **New role insert:** after Supervisor (sub-division) / before Dean (division); anchors locked or snap-normalized on Save.
- **Associate Dean:** custom (not system). System roles = **Dean** + **Supervisor** only.
- **Reattach** (drag owner to another template): drop `RoleAssignment`s for roles not in the target; keep overlapping; mark missing red.
- **Raiseable:** template may suggest a default on `HierarchyRole`; **overridable per sub-division** via a thin override store.
- **Delete template:** only when unused; **default templates never deletable**.
- **Save vs staffing:** hierarchy page **Save commits structure** even if owners go red. Incomplete owners **cannot accept new submissions**. Create wizards **cannot finish** until fully staffed. In-flight: skip unstaffed steps; **block** removing a role that is the current cursor for live requests (v1).

---

## Phase A — independent, do first (unchanged)

### A1. Scoring aggregation bug
> Sum `points_awarded` by its own stored sign only — no join back to categories/sub_divisions/divisions.

### A2. Profile field editability
> `Permission` model + admin toggle matrix for `edit_own_phone` / `edit_own_address` / `edit_own_photo`.

### A3. Archive cascades to auto-reject pending requests
> In `Category#archive!`, reject non-terminal requests with `"Automatically rejected — category archived"`.

---

## Phase B — the role hierarchy engine (shared templates)

### B1. Schema

> Create:
> - `Hierarchy`: `name` (unique), `scope` (`division`/`sub_division`), `is_default` (exactly one default per scope). Seed "Default Division Hierarchy" (Dean only) and "Default Sub-division Hierarchy" (Supervisor only).
> - `ReviewRole`: `name` (globally unique, case-insensitive), `scope`, `raiseable_on_behalf_eligible` (sub_division only), `system_role`. System: Dean + Supervisor only. Associate Dean is custom if present.
> - `HierarchyRole`: `hierarchy_id`, `review_role_id`, `position`, `can_raise_on_behalf` (**template default only**).
> - `RoleAssignment`: unchanged person binding (`user`, `review_role`, exactly one of `division`/`sub_division`).
> - `sub_division_raiseable_overrides`: `sub_division_id`, `review_role_id`, `can_raise_on_behalf` — effective raiseable = override ?? template default ?? false.
>
> Add `hierarchy_id` to `divisions` and `sub_divisions` (FK → Hierarchy, matching scope).
> Cursor: migrate `achievement_requests` from `current_step_id` → `current_review_role_id`.

### B2. Data migration

> Group existing per-owner `HierarchyStep` signatures into shared `Hierarchy` templates (identical ordered role lists share one template). Point each division/sub at its template. Preserve all `RoleAssignment`s. Copy per-sub `can_raise_on_behalf` into overrides where it differs from the template default. Map in-flight `current_step_id` → that step's `review_role_id`.

### B3. Resolver

> Resolve through `sub_division.hierarchy.hierarchy_roles` then `division.hierarchy.hierarchy_roles`, looking up live `RoleAssignment`s and skipping unstaffed roles. Always fresh. Effective raiseable uses per-sub override. Specs: skip unstaffed; mid-flight template edits change next/previous; deleted hierarchy role skipped.

### B4–B5. State machine + queues

> Already on `in_review`/`reverted`/`approved`/`rejected`. Cut cursor to `current_review_role_id`. Queues: "requests where I am the current_reviewer."

### B6. Hierarchy Templates UI

> Two sections (Division / Sub-division), side-by-side cards, default last, `+` card.
> Flowchart + drag list (**final on top**). Add role / create role (scope inferred). Attached owners as drag targets; **red if unstaffed**.
> New role insert: after Supervisor / before Dean.
> **Single Save** commits structure + reattachments (not blocked by red). Incomplete owners gated on intake.
> Usage counts on pickers. Delete unused non-default templates only.
> Per-sub raiseable toggle on sub-division staffing UI.

### B7. Phased create wizards

> **Division:** name + `div_type` → choose/create hierarchy → assign every role (faculty with zero assignments) → done.
> **Sub-division:** name + parent division → choose/create hierarchy → assign each role (zero assignments OR same role type elsewhere) → done.
> Inline create hierarchy persists a real global `Hierarchy`.

### B8. Drop legacy

> After confidence: drop `hierarchy_steps` and any remaining legacy references. `dean_user_id`/`supervisor_user_id` already removed if present.
