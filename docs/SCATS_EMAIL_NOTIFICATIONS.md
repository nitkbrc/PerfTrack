# SCATS — Email Notifications (new addition)
 
Every role gets emailed whenever a request lands in their court. Ties directly into the Request Timeline feature: "fresh vs. resubmitted" is literally `RequestVersion.version_number`, and every email links straight into that timeline.
 
## Schema addition (deferred — not implemented)

~~`users.phone` — string, nullable, no format validation. Editable on the profile page, never required.~~

**Not done.** Phone already exists on `users` and stays **required** (admin/CSV). Profile remains view-only for phone. Step 1 below is commented out on purpose; revisit only if product wants optional self-serve phone later.

## The rule, stated once
 
- **Dean or Supervisor:** notified every time a request lands in their queue for action — fresh, forwarded, or coming back after a clarification loop.
- **Student:** notified on revert (fix and resubmit), and on the dean's final decision — approve or reject, always.
- **The originating Supervisor** (only when the request was *raised by them on the student's behalf*, not when they merely forwarded something the student submitted themselves): also notified on the dean's final decision, approve **or** reject — same logic either way, they vouched for it and deserve to know the outcome regardless of which way it went.
"Originating supervisor" is derived the same way the rest of the system already tells Path A from Path B — the actor on the request's first `ReqHistory` row. If that's the student, it's a normal forward and only the student gets the final-decision email. If it's a supervisor, both get it.
 
## Trigger map
 
| Transition | Recipient(s) | Mailer method |
|---|---|---|
| Student submits (fresh) | Supervisor | `submitted_to_supervisor` |
| Supervisor raises on behalf of student | Dean | `raised_on_behalf` |
| Supervisor approves & forwards | Dean | `forwarded_to_dean(is_reforward: false)` |
| Dean reverts for clarification | Supervisor | `reverted_to_supervisor` |
| Supervisor reverts to student | Student | `reverted_to_student` |
| Supervisor clarifies & re-forwards | Dean | `forwarded_to_dean(is_reforward: true)` |
| Dean approves — Path A origin | Student only | `approved_notification(recipient: student)` |
| Dean approves — Path B origin | Student + originating Supervisor | `approved_notification` called twice, once per recipient |
| Dean rejects — Path A origin | Student only | `rejected_notification(recipient: student)` |
| Dean rejects — Path B origin | Student + originating Supervisor | `rejected_notification` called twice |
| Supervisor rejects directly (Submitted → Rejected) | Student only | `rejected_notification(recipient: student)` |
 
## What every email contains
 
- Actor identity: name, email, phone (if set)
- Student's name/USN/department — always, even when the student is the recipient
- Category → Sub-division → Division the request belongs to
- Fresh submission or resubmission, and which version number
- The comment/reason, when the action included one (revert, reject)
- A direct link into the request's timeline
## Cursor prompts — do in order
 
<!-- **1. Phone field**
> Add an optional `phone` string column to `users` — nullable, no format validation, just free text. Add a field for it on the existing profile/settings page. Not required anywhere, including signup. -->
 
**2. Mailer + templates**
> Add `premailer-rails` (inlines CSS automatically, since raw modern CSS doesn't render reliably across email clients). Create a `RequestMailer` with these methods, each rendering a professional HTML email:
> - `submitted_to_supervisor`
> - `raised_on_behalf`
> - `forwarded_to_dean(is_reforward: false)` — `is_reforward: true` changes the framing text for a re-forward after a dean revert, same template otherwise
> - `reverted_to_supervisor`
> - `reverted_to_student`
> - `approved_notification(recipient:)` — called once per recipient
> - `rejected_notification(recipient:)` — called once per recipient
>
> Every email includes: actor identity (name, email, phone if present), the student's name/usn/department regardless of recipient, the category/sub-division/division, fresh-vs-resubmission with version number (from RequestVersion), any comment/reason attached to the action, and a link into the request's timeline.

**Expected output:** any mailer method can be called from `bin/rails runner` or the console (e.g. `.deliver_now`) and sends via **Gmail SMTP** — the live development delivery method (see “Sending real email now” below). Mail is styled and readable; test env still uses the `:test` adapter and never hits the network.

**3. Wire up triggers**
> Call the corresponding RequestMailer method via `deliver_later` at each state transition, per the trigger map. For the dean's final decision specifically (approve or reject): always notify the student; additionally, look up the actor on the request's first ReqHistory row — if that actor is a Supervisor rather than the Student, also notify that supervisor with the same mailer method, same event, second recipient. A supervisor's direct reject at the Submitted stage only ever notifies the student — a request that reaches that stage is always student-originated.
 
**Expected output:** approving or rejecting a Path B (supervisor-initiated) request enqueues exactly two mail deliveries; every other transition, including approve/reject on a normal Path A request, enqueues exactly one, to the right person.
 
**4. Tests**
> Write mailer specs for every RequestMailer method: correct recipient, sensible subject, body includes actor identity, student details, category, and the correct version number. Add request specs confirming the right email(s) actually get enqueued at each transition — including one specifically proving a Path A approval enqueues one email and a Path B approval enqueues two.
 
## Sending real email now (Gmail SMTP)
 
Resolved earlier than planned — was going to wait until deployment, doing it now instead. This replaces `letter_opener` in development (which only *previewed* mail); development now sends for real.
 
**Manual setup (browser, not Cursor — one time):**
1. Pick the Gmail account to send from — a dedicated project account is cleaner than a personal one (professional sender identity, doesn't expose your own address once real people are getting these emails), but technically either works and nothing below changes based on which.
2. `myaccount.google.com` → Security → confirm **2-Step Verification** is on (turn it on if not — Gmail no longer allows plain-password SMTP auth at all, an App Password is mandatory).
3. Security → **App Passwords** → generate one, name it something like "SCATS Rails" → copy the 16-character password shown.
**Store credentials** — `.env` (already gitignored):
```
GMAIL_USERNAME=your-address@gmail.com
GMAIL_APP_PASSWORD=xxxxxxxxxxxxxxxx
```
 
**Cursor prompt 1 — configure ActionMailer for real Gmail SMTP:**
> Replace the letter_opener development delivery method with real Gmail SMTP. In `config/environments/development.rb`, set `action_mailer.delivery_method = :smtp` with: address `smtp.gmail.com`, port 587, `user_name`/`password` from `ENV["GMAIL_USERNAME"]`/`ENV["GMAIL_APP_PASSWORD"]` (via dotenv-rails, already in the Gemfile), `authentication: :plain`, `enable_starttls_auto: true`. Set `config.action_mailer.default_url_options = { host: "localhost", port: 3000 }` — without this, any mailer view using a `_url` helper for the timeline link raises an error. Set RequestMailer's default `from` to `"SCATS <#{ENV['GMAIL_USERNAME']}>"`. Leave the test environment untouched — specs should keep using the test adapter, never real SMTP.
 
**Expected output:** `bin/rails server` still boots clean; no mailer specs suddenly try to hit the real network.
 
**Cursor prompt 2 — verify it actually works:**
> In the Rails console, trigger one RequestMailer method against a seeded request with `.deliver_now` (not `deliver_later`, so you see the result immediately) and confirm it errors or succeeds clearly.
 
**Expected output:** a real email lands in a real inbox within a minute or two — check spam the first time, Gmail sometimes flags a freshly-configured sender initially. Once confirmed, switch back to `deliver_later` everywhere per Step 3's plan.
 
**Worth knowing, not urgent:** Gmail SMTP caps regular accounts at 500 sends/day (2000 for Workspace) — plenty for now, but if this ever gets deployed at real scale, a dedicated transactional provider (Postmark, SendGrid, Resend) is still the better long-term answer — better deliverability, and Gmail's terms aren't really meant for automated app traffic at volume. Fine to revisit that later; not a blocker now.
 
---

# Implementation record (July 2026)

What was actually built. Glance here to recover context for this phase.

## Product intent (locked)

Automated emails when a request **lands in someone's court**, plus outcome emails on final decisions:

- Dean / supervisor get mail when work arrives for them (submit, initiate, forward, reforward, dean revert).
- Student gets mail on revert, reject, and approve.
- **Path B** (first `ReqHistory` actor is the supervisor who raised on behalf of the student): on **dean approve or dean reject**, both **student and originating supervisor** get mail.
- **Path A** (student-initiated): dean approve/reject → **student only**.
- Supervisor direct reject (Submitted → Rejected) → **student only**.
- Fully automatic via `deliver_later`.
- **Phone left as-is** (already required; no profile phone edit for this feature).

## What shipped

### Gems & config

| Piece | Where |
|---|---|
| `premailer-rails` | Gemfile (inlines CSS for HTML mail) |
| `letter_opener` | still in Gemfile `development`, **not used** for delivery anymore |
| `dotenv-rails` | loads `.env` in development/test |
| Dev delivery | Gmail SMTP (`smtp.gmail.com:587`) via `GMAIL_USERNAME` / `GMAIL_APP_PASSWORD` |
| Test delivery | `:test` + Active Job `:test` (never hits the network) |
| From address | `SCATS <#{ENV['GMAIL_USERNAME']}>` (fallback `noreply@scats.local` in test) |
| Secrets template | [`.env.example`](../.env.example) (real `.env` gitignored) |

Production SMTP / transactional provider still deferred for deploy at scale.

### Mailer

- [`app/mailers/request_mailer.rb`](../app/mailers/request_mailer.rb)
- Layout + HTML/text templates under `app/views/request_mailer/`
- Shared details: actor, student, category path, version, comment, timeline URL by recipient role

Queue recipients: `category.sub_division.supervisor` / `.division.dean`.  
Path B final-decision CC: **`originating_supervisor`** = actor on the first `ReqHistory` row when that actor is not the student.

### Triggers

Hooks on [`AchievementRequest`](../app/models/achievement_request.rb) after the DB transaction commits. Shared helper: `enqueue_final_decision_mails!`.

| Event | Mail |
|---|---|
| Student submit / resubmit | `submitted_to_supervisor` |
| Supervisor initiate | `raised_on_behalf` |
| Supervisor approve / reforward | `forwarded_to_dean` |
| Dean revert | `reverted_to_supervisor` |
| Supervisor revert | `reverted_to_student` |
| Supervisor reject | `rejected_notification` ×1 (student) |
| Dean reject Path A | `rejected_notification` ×1 (student) |
| Dean reject Path B | `rejected_notification` ×2 (student + originating supervisor) |
| Dean approve Path A | `approved_notification` ×1 (student) |
| Dean approve Path B | `approved_notification` ×2 (student + originating supervisor) |
| `revise!` draft | no mail |

In-app `DeanApprovalNotificationJob` still runs on dean approve alongside email.

### Specs

- [`spec/mailers/request_mailer_spec.rb`](../spec/mailers/request_mailer_spec.rb)
- [`spec/models/request_mail_notifications_spec.rb`](../spec/models/request_mail_notifications_spec.rb) — enqueue counts including Path A/B approve **and** reject

### How to verify locally

1. Ensure `.env` has Gmail App Password credentials; `bundle install`.
2. `bin/rails s` / console: `RequestMailer.…(…).deliver_now` should land in a real inbox (check spam once).
3. App flows use `deliver_later` (needs the server / Solid Queue in production).

### Still deferred

- Production SMTP / transactional provider (Postmark, SendGrid, Resend) at real scale.
- Making phone optional / self-serve profile edit.
