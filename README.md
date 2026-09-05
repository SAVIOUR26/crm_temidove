# Temidove CRM

Offline-first Windows CRM for Temidove Smart Solutions — student
inquiries, batch enrollment, and monthly fee payment tracking in one
place, replacing a PHP dashboard and a set of hand-maintained Excel
payment trackers.

Full project context, architecture decisions, and current build status
are in **[CLAUDE.md](./CLAUDE.md)**. Analysis of the two legacy systems
this replaces is in **[legacy/NOTES.md](./legacy/NOTES.md)**.

## Quick start

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run -d windows
```

## Status

Core v1 feature set is built: a dashboard overview, department/batch/
student drill-down, student detail with payment history, payment
reminders + recording, admin-gated login (an admin account added on
first run controls who else gets access), a full modern UI/branding
pass, and both legacy-data import paths (Excel batch trackers and CSV
exports of the old PHP app's tables) commit to the database.
Reports/export is deliberately deferred — see "Current state" in
`CLAUDE.md` for the full picture and open questions to confirm with
the client before shipping.

## CI

Every push to `main` builds a single Windows installer
(`TemidoveCRM-Setup.exe`, via `.github/workflows/build-windows.yml`),
downloadable from the Actions tab. Pushing a version tag (e.g.
`v0.1.0`) additionally publishes a GitHub Release with the installer
attached.
