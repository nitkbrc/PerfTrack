# SCATS — Email Notifications (new addition)

Every role gets emailed whenever a request lands in their court — not just dean/supervisor. Ties directly into the Request Timeline feature: "fresh vs. resubmitted" is literally `RequestVersion.version_number`, and every email links straight into that timeline.

## Schema addition

`users.phone` — string, nullable, no format validation. Editable on the profile page, never required.

## Trigger map

| Transition | Recipient(s) | Mailer method |
|---|---|---|
| Student submits (fresh) | Supervisor | `submitted_to_supervisor` |
| Supervisor raises on behalf of student | Dean | `raised_on_behalf` |
| Supervisor approves & forwards | Dean | `forwarded_to_dean(is_reforward: false)` |
| Dean reverts for clarification | Supervisor | `reverted_to_supervisor` |
| Supervisor reverts to student | Student | `reverted_to_student` |
| Supervisor clarifies & re-forwards | Dean | `forwarded_to_dean(is_reforward: true)` |
| Dean approves | Student **and** the forwarding Supervisor (two deliveries) | `approved_notification(recipient:)` |
| Reject (either stage) | Student always; Supervisor too if it happened at the dean stage | `rejected_notification(recipient:)` |

## What every email contains

- Actor identity: name, email, phone (if set)
- Student's name/USN/department — always, even when the student is the recipient, for consistent transparency
- Category → Sub-division → Division the request belongs to
- Fresh submission or resubmission, and which version number
- The comment/reason, when the action included one (revert, reject)
- A direct link into the request's timeline

## Cursor prompts — do in order

**1. Phone field**
> Add an optional `phone` string column to `users` — nullable, no format validation, just free text. Add a field for it on the existing profile/settings page. Not required anywhere, including signup.

**2. Mailer + templates**
> Add the `letter_opener` gem for development (previews sent mail in the browser instead of actually sending) and `premailer-rails` (inlines CSS automatically, since raw modern CSS doesn't render reliably across email clients). Create a `RequestMailer` with these methods, each rendering a professional HTML email:
> - `submitted_to_supervisor`
> - `raised_on_behalf`
> - `forwarded_to_dean(is_reforward: false)` — `is_reforward: true` changes the framing text for a re-forward after a dean revert, same template otherwise
> - `reverted_to_supervisor`
> - `reverted_to_student`
> - `approved_notification(recipient:)` — called once per recipient (student, forwarding supervisor)
> - `rejected_notification(recipient:)` — same pattern
>
> Every email includes: actor identity (name, email, phone if present), the student's name/usn/department regardless of recipient, the category/sub-division/division, fresh-vs-resubmission with version number (from RequestVersion), any comment/reason attached to the action, and a link into the request's timeline.

**Expected output:** `bin/rails runner` or the Rails console can call any mailer method and it opens correctly in the browser via letter_opener, styled and readable, not a wall of unstyled text.

**3. Wire up triggers**
> Call the corresponding RequestMailer method via `deliver_later` at each state transition, per the trigger map: submission → `submitted_to_supervisor`; supervisor-initiated → `raised_on_behalf`; supervisor approve → `forwarded_to_dean(is_reforward: false)`; dean revert → `reverted_to_supervisor`; supervisor revert → `reverted_to_student`; supervisor re-forward after a dean revert → `forwarded_to_dean(is_reforward: true)`; dean approve → `approved_notification` to both the student and the original forwarding supervisor; reject at either stage → `rejected_notification` to the student, plus the supervisor too if the reject happened at the dean stage.

**Expected output:** approving a request as dean enqueues exactly two mail deliveries, not one; every other transition enqueues exactly one, to the right person.

**4. Tests**
> Write mailer specs for every RequestMailer method: correct recipient, sensible subject, body includes actor identity, student details, category, and the correct version number. Add request specs confirming the right email(s) actually get enqueued at each state transition — not just that the mailer renders in isolation.

## Deferred, on purpose

No real SMTP provider picked yet — same "local now, decide at deployment" pattern as file storage. `letter_opener` covers local dev completely; when you're ready to deploy, that's when a transactional email provider (Postmark, SendGrid, Resend, etc.) gets chosen and configured, not before.
