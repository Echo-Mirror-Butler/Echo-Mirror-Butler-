## Description
This pull request introduces an automated dependency vulnerability scanning step using Google's `osv-scanner`. This ensures that any compromised, outdated, or vulnerable dependencies introduced in the Flutter application or Serverpod server are caught before they can be merged.

### Changes Made
- **GitHub Workflow**: Added a new `.github/workflows/security.yml` workflow that executes `google/osv-scanner-action@v1` on all pull requests targeting the `main` and `development` branches.
- **Scheduled Scans**: Added a weekly scheduled cron job (Every Monday at 3:00 AM) to the security workflow to continually check existing dependencies against newly discovered CVEs.
- **Dual Verification**: Configured the pipeline to scan the dependencies of both the Flutter application and the Serverpod server by specifically targeting their `pubspec.lock` files.

### Acceptance Criteria Covered
- [x] `.github/workflows/security.yml` created.
- [x] Workflow runs on PRs to `main` and `development`.
- [x] Workflow runs on a weekly schedule.
- [x] Both `pubspec.lock` files are scanned (app + server).
- [x] CI fails if a vulnerability is found.

**Note to Reviewers**: Please ensure `pubspec.lock` files for both the root project and the `echomirror_server/echomirror_server_server` project are generated via `flutter pub get` and committed on this branch before approving, otherwise the lockfile scanner action will fail.

Closes #61
