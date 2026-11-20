# Student System

A working implementation of the **Student System flowchart**: login / register â†’ services
page â†’ seven student services, plus a lecturer portal for approving every service
request.

Built with Node.js, Express 5 and PostgreSQL.

---

## Quick start

```bash
npm install          # also creates the lockfile on a fresh checkout
npm run db:migrate   # create/upgrade the schema (idempotent)
npm run db:seed      # seed schools, programs, courses and a lecturer account
npm start            # http://127.0.0.1:2000
```

The server binds to `127.0.0.1` by default. Set `HOST=0.0.0.0` only when a
reverse proxy or container needs to reach it.

Run the integration tests against a **disposable** database whose name contains
`test` (the suite wipes and re-seeds it):

```bash
# bash
TEST_DATABASE_URL=postgres://postgres:password@127.0.0.1:5432/student_system_test npm test

# PowerShell
$env:TEST_DATABASE_URL='postgres://postgres:password@127.0.0.1:5432/student_system_test'; npm test
```

### Upgrading an existing installation

```bash
npm install          # helmet and express-rate-limit are new dependencies
npm run db:migrate   # adds students/hods.token_version and the course-code index
npm start
```

Existing sessions keep working until they expire; changing or resetting a
password immediately revokes every session for that account.

Configuration lives in `.env` (copy `.env.example` if it is missing):

| Variable | Purpose |
|---|---|
| `PORT` | HTTP port (default `2000`) |
| `HOST` | Interface to bind (default `127.0.0.1`; use `0.0.0.0` only behind a proxy) |
| `TRUST_PROXY` | Set to `1` behind a trusted reverse proxy so rate limits see real client IPs |
| `DATABASE_URL` | `postgres://user:password@host:5432/student_system` |
| `SESSION_SECRET` | HMAC key for the signed session cookie (required in production) |
| `MAX_COURSES` | Maximum courses per semester (flowchart: **6**) |
| `REMARK_FEE` | Remark fee in Kwacha (flowchart: **K525**) |

## Sign-in details

The seed script creates a lecturer account **only when the school does not
already have one**, and re-running `npm run db:seed` never changes an existing
password. **Exactly one HOD per school** is enforced by a unique database index.

| Role | Email | Password |
|---|---|---|
| Lecturer / HOD | `hod@university.edu` | `HodPass12345` (first seed in development only) |

In production, set `HOD_PASSWORD` before the first seed; the script refuses to
create the account with the demo password. Change it with:

```bash
node scripts/set-hod-password.js hod@university.edu "a-new-password"
```

Changing the password also bumps the account's session version, so every
existing lecturer session is signed out immediately.

### System administrator portal

The administrator portal at `/admin.html` can create and manage HOD accounts.
Administrators can create one active HOD for a school, update a HOD's name or
email, reset a password, and deactivate or reactivate an account. Deactivation
immediately revokes existing HOD sessions and releases that school's active
HOD assignment. Account changes are recorded in `admin_audit_log`.

After applying all database migrations, bootstrap the first administrator once
from PowerShell. Use a private password prompt so the password is not written
into shell history:

```powershell
$env:ADMIN_PASSWORD = Read-Host "First administrator password (12-72 characters)" -AsSecureString |
  ForEach-Object { [System.Net.NetworkCredential]::new('', $_).Password }
try {
  npm run create-admin -- --name "System Administrator" --email admin@university.edu
} finally {
  Remove-Item Env:ADMIN_PASSWORD -ErrorAction SilentlyContinue
}
```

The bootstrap command is insert-only and refuses to run once an administrator
exists. Sign in at `/admin.html`. When creating or resetting an HOD, set a
temporary password of 12-72 characters and give it to that HOD privately. They
must change it at first sign-in before accessing requests. Resetting or
deactivating an HOD revokes their existing sessions. HODs can only process the
queue for their assigned school.

The same portal manages schools, programs, and courses. It prevents duplicate
school names and program names within a school, and course codes are globally
unique. Deactivation is reversible and hides items from new student forms;
existing enrollments, requests, and history remain stored. If a parent school
or program is inactive, its child reference rows are also hidden from student
forms until the parent is reactivated. Reference-data changes are recorded in
the administrator audit log.

Run `npm run db:migrate` before starting the upgraded application. The new
migrations add administrator and audit tables, HOD account status fields, and
active flags for schools, programs, and courses. Existing records remain active
by default; existing HOD accounts and passwords are preserved.

### Creating lecturer accounts

There is deliberately **no public lecturer sign-up** â€” the HOD approves every
service request, so accounts are provisioned by an administrator. The seed
creates one Engineering account; each school can have **at most one** HOD:

```bash
# bash: password kept out of shell history
HOD_PASSWORD='a-long-password' node scripts/create-hod.js \
  --email jane@university.edu \
  --name "Dr Jane Banda" \
  --school "School of Business"
```

```powershell
# PowerShell
$env:HOD_PASSWORD='a-long-password'; npm run create-hod -- --email jane@university.edu --name "Dr Jane Banda" --school "School of Business"
```

`--school` accepts either the numeric id or the school name. Passwords must be
12â€“72 characters. The script is insert-only: use `set-hod-password` to reset an
existing account.

### Adding schools, programs and courses

These are rows in three existing tables â€” no migration is needed. The CLI is
idempotent for names/codes that already exist:

```powershell
cd C:\Users\ThE ViRuS\Desktop\students

npm run add-school -- --name "School of Law"

npm run add-program -- --name "Bachelor of Laws" --school "School of Law"

npm run add-course -- --code LAW101 --name "Introduction to Law" --program "Bachelor of Laws"
```

- `--school` and `--program` accept the numeric id or the name.
- Course codes are **globally unique** and are stored in upper case.
- Program names may repeat across schools; if a name is ambiguous, pass
  `--school` or the numeric program id.
- After creating the school, create its one HOD with `npm run create-hod`.

### Password reset by email

Students can request a link at `/forgot.html`; it opens `/reset.html`.

- Tokens are single-use, expire after 30 minutes (configurable with
  `PASSWORD_RESET_MINUTES`), and only their SHA-256 hash is stored.
- The request endpoint always returns the same message, whether or not the
  email exists.
- A successful reset bumps `token_version`, signing out every existing session.
- Requests are limited to 5 per 15 minutes per address, with a 60-second
  per-account cooldown.

Delivery is selected with `MAIL_TRANSPORT`:

| Value | Behaviour |
|---|---|
| `console` (default) | Prints the reset link in the server log â€” development only |
| `smtp` | Real delivery through `SMTP_HOST` / `SMTP_PORT` / `SMTP_USER` / `SMTP_PASS` |
| `memory` | Captured in memory for the test suite |

There is no bundled mail provider and no mailbox is created for you. For real
delivery, use a transactional SMTP provider â€” Brevo, Mailgun, Amazon SES,
Microsoft 365, or your universityâ€™s relay â€” and set `MAIL_FROM` to an address on
the authenticated sending domain. Gmail SMTP with an app password works for a
small demo but is not recommended for production.

```bash
MAIL_TRANSPORT=smtp \
MAIL_FROM="Student System <no-reply@school.edu>" \
SMTP_HOST=smtp-relay.brevo.com SMTP_PORT=587 \
SMTP_USER=your-user SMTP_PASS=your-password \
PUBLIC_BASE_URL=https://portal.school.edu \
npm start
```

`PUBLIC_BASE_URL` must be the address students actually open; it is what the
email links point at. Deliverability depends on the sending domainâ€™s SPF/DKIM
records â€” without them, real messages are likely to be marked as spam.

Students register through the web form (school â†’ program are dropdowns).

## The flows

| # | Service | Behaviour |
|---|---|---|
| 1 | **Change program** | Submits a request for the school HOD. If approved, the program/school/year change and **all currently enrolled courses are dropped**. Different school â†’ restarts at first year. |
| 2 | **Overload course** | Submits a course-addition request; the HOD approves it before the student is enrolled. The 6-course cap is checked when requesting and re-checked at approval. Course codes are case-insensitive. |
| 3 | **Drop a course** | Submits a drop request; the course stays enrolled until the HOD approves it. |
| 4 | **Missing result** | Creates a ticket in the HOD inbox. The HOD marks it `resolved` or `not_found` with a note, and the student is emailed. |
| 5 | **Remark** | Creates the request for K525; the clearly labelled **simulated** â€œPay K525â€ step submits it. The HOD then marks it `processed` or `rejected`, and the student is emailed. |
| 6 | **Change course code** | Creates a pending request; nothing changes until the HOD approves. Approval renames the course (`ON UPDATE CASCADE` keeps enrollments in sync). |
| 7 | **HOD dashboard** | `/hod.html` â€” one inbox with tabs for approvals, missing results, remarks and the HODâ€™s own decision history, plus a â€œYour accessâ€ panel. Every decision emails the student. |

## Project layout

```
student-system/
â”œâ”€â”€ server.js              entry point (starts Express, checks the DB)
â”œâ”€â”€ app.js                 app wiring, static files, error handling
â”œâ”€â”€ config.js              env loading + business rules
â”œâ”€â”€ db.js                  PostgreSQL pool
â”œâ”€â”€ lib/mailer.js          reset and decision email (console / SMTP / test capture)
â”œâ”€â”€ middleware/auth.js     signed session cookie, role guards
â”œâ”€â”€ middleware/rate-limit.js  API / login / registration / write limits
â”œâ”€â”€ routes/
â”‚   â”œâ”€â”€ auth.js            register / login / logout / me / change password
â”‚   â”œâ”€â”€ reference.js       schools, programs, courses (public)
â”‚   â”œâ”€â”€ student.js         the seven student services
â”‚   â””â”€â”€ hod.js             lecturer login, inbox, decisions and history
â”œâ”€â”€ migrations/            SQL, applied in filename order
â”œâ”€â”€ scripts/               migrate, seed, create-hod, add-reference, set-hod-password
â”œâ”€â”€ test/                  integration tests (node:test)
â”œâ”€â”€ public/                HTML, CSS, browser JS
â””â”€â”€ docs/                  flowchart, Postman files and the generated PDFs
```

## Documentation

Three documents ship in `docs/`, each as a PDF plus an editable DOCX:

| Document | Covers |
|---|---|
| `Student-System-Cheat-Sheet.pdf` | Running the server, logins, the ten-minute demo, troubleshooting |
| `Student-System-API-Reference.pdf` | All 23 endpoints with request and response examples |
| `Student-System-Technical-Documentation.pdf` | Architecture, file-by-file code reference, data model, security, operations |

The generators live in `docs/source/` (Python + `python-docx`, diagrams with Pillow):

```bash
cd docs/source
python make_diagrams.py
python build_cheatsheet.py && python build_api.py && python build_docs.py
```

## API summary

The current application also includes migrations 005 and 006 for administrator
accounts and reversible school, program, and course deactivation. Apply the
migrations before using the corresponding administrator portal sections.

| Method | Path | Who |
|---|---|---|
| `POST` | `/api/auth/register` | public |
| `POST` | `/api/auth/login` | public |
| `POST` | `/api/auth/forgot-password` | public |
| `POST` | `/api/auth/reset-password` | public |
| `POST` | `/api/auth/logout` | any |
| `GET` | `/api/auth/me` | student |
| `POST` | `/api/auth/change-password` | student |
| `GET` | `/api/reference/schools` | public |
| `GET` | `/api/reference/programs?schoolId=` | public |
| `GET` | `/api/reference/courses?schoolId=` | public |
| `GET` | `/api/student/dashboard` | student |
| `POST` | `/api/student/change-program` | student |
| `POST` | `/api/student/courses` | student |
| `DELETE` | `/api/student/courses/:code` | student |
| `POST` | `/api/student/missing-results` | student |
| `POST` | `/api/student/remarks` | student |
| `POST` | `/api/student/remarks/:id/pay` | student |
| `POST` | `/api/student/course-code-change` | student |
| `GET` | `/api/student/requests` | student |
| `POST` | `/api/hod/login` Â· `/logout` | lecturer |
| `GET` | `/api/hod/me` | lecturer |
| `GET` | `/api/hod/inbox` | lecturer |
| `GET` | `/api/hod/history` | lecturer |
| `GET` | `/api/admin/reference` | administrator |
| `POST` | `/api/admin/schools` · `/programs` · `/courses` | administrator |
| `PATCH` | `/api/admin/reference/:kind/:id` | administrator |
| `PATCH` | `/api/hod/approvals/:id` | lecturer |
| `PATCH` | `/api/hod/missing-results/:id` | lecturer |
| `PATCH` | `/api/hod/remarks/:id` | lecturer |
| `GET` | `/api/hod/requests` Â· `PATCH /:id` | lecturer (legacy alias) |
| `GET` | `/api/health` | public |

## Notes

- Passwords are hashed with bcrypt (cost 12).
- Sessions are HttpOnly, SameSite=Lax HMAC-signed cookies. Each token carries a
  `token_version` that is checked against the database on every request, so
  changing or resetting a password revokes older sessions. Students and
  lecturers use separate cookies and can be signed in on the same browser.
- Rate limits: 10 failed logins per 15 minutes, 20 registrations per hour,
  30 student writes per hour, and 300 API requests per minute per address.
- Security headers (CSP, `X-Content-Type-Options`, frame protection, HSTS) are
  set with Helmet.
- In production the session cookie is `Secure`, so the app must be reached over
  HTTPS (terminate TLS at a reverse proxy and set `TRUST_PROXY=1`).
- Only `public/` is served statically; `.env`, source files and `node_modules` are not reachable.
- `migrations/001`â€“`004` are idempotent and keep older databases up to date; `004`
  adds the request school snapshots and the one-HOD-per-school constraint.
- Email delivery is implemented for password resets and HOD decisions; real
  payments remain intentionally out of scope and are labelled simulated.
- The PDFs in `docs/` were generated for version 2.0. This README is
  authoritative for the 2.x changes.

## Environment check and backup / recovery

Before a demo or deployment, run `npm run doctor`. It checks the Node.js version,
PostgreSQL connectivity, core database tables, and reference data without changing
the database. A nonzero exit code means a required check failed; warnings point
to optional setup such as missing demo reference data or production email.

### Database backup

Create backups outside the project folder so they are not served or committed.
Use the same PostgreSQL client tools as the database server:

```powershell
pg_dump --format=custom --no-owner --file student-system-YYYYMMDD.backup "$env:DATABASE_URL"
```

Protect the backup as sensitive student data. Store it in an access-controlled,
encrypted location and retain it according to your institution's policy. Do not
put credentials directly in shell history or share backups over public links.

### Restore drill

Restore to a separate, empty recovery database first; never test a restore over
the live database. Create the target database, then run:

```powershell
pg_restore --clean --if-exists --no-owner --dbname "$env:RECOVERY_DATABASE_URL" student-system-YYYYMMDD.backup
```

Verify that the restored application can start against the recovery database and
that expected student, course, and request records are present. Record the date,
backup file, restore target, and result. Keep the current database untouched until
recovery has been verified and an administrator approves any production cutover.

