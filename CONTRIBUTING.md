# Contributing to EchoMirror Butler

Thank you for your interest in contributing to EchoMirror Butler! We welcome contributions of all kinds, from bug fixes to new features.

## How to Contribute

1. **Fork the repository** on GitHub.
2. **Clone your fork** locally.
3. **Create a new branch** for your changes.
4. **Make your changes** and commit them with descriptive messages.
5. **Push your changes** to your fork.
6. **Submit a Pull Request** to the main repository.

## Feedback and Questions

If you have any questions or feedback, please open an issue or start a discussion on GitHub.

---

*Wellness is better together.*
Thank you for contributing! Please read this guide before opening a PR.

---

## 1. Getting Started

### Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install) 3.10+
- [Dart SDK](https://dart.dev/get-dart) 3.10+
- [Docker Desktop](https://www.docker.com/products/docker-desktop/) (must be running)
- [Supabase CLI](https://supabase.com/docs/guides/cli/getting-started)
- [Node.js](https://nodejs.org/) 18+ (for edge functions)

### Fork & Clone

```bash
git clone https://github.com/<your-username>/Echo-Mirror-Butler-.git
cd Echo-Mirror-Butler-
flutter pub get
```

### Before pushing

Run these from the repo root to ensure formatting, analysis, and tests pass:

```bash
dart format lib test backend   # fix formatting
dart analyze lib test          # check for errors
flutter test                   # run tests
```

> **Tip:** Enable the pre-push hook to catch formatting issues automatically:
> ```bash
> git config core.hooksPath .githooks
> ```

If the CI formatting check fails, run `dart format lib test backend` locally and commit the changes.

### Local Setup

Run the app with the required `dart-define` env vars:

```bash
flutter run \
  --dart-define=SUPABASE_URL=http://127.0.0.1:54321 \
  --dart-define=SUPABASE_ANON_KEY=<your-local-anon-key>
```

> Get `SUPABASE_ANON_KEY` from the output of `supabase start`. See [supabase/README.md](supabase/README.md) for full local Supabase setup.

---

## 2. How to Pick Up an Issue

1. Browse [labelled issues](https://github.com/Echo-Mirror-Butler/Echo-Mirror-Butler-/issues) — look for `good first issue` or `help wanted`
2. Comment on the issue to claim it before starting work
3. One issue per contributor at a time — finish or unassign before picking up another

---

## 3. Branching Strategy

| Branch | Purpose |
|---|---|
| `main` | Production — do **not** target PRs here |
| `development` | Default branch — all PRs target this |
| `feature/issue-{number}-short-description` | New features |
| `fix/issue-{number}-short-description` | Bug fixes |

Examples:
```
feature/issue-42-stellar-gifting-ui
fix/issue-87-auth-session-expiry
```

Create your branch from `development`:
```bash
git checkout development
git pull origin development
git checkout -b feature/issue-{number}-short-description
```

---

## 4. PR Checklist

Before opening a PR, confirm all of the following:

- [ ] Branch is named correctly (`feature/issue-{number}-...` or `fix/issue-{number}-...`)
- [ ] PR targets `development` (not `main`)
- [ ] PR description explains **what** changed and **why**
- [ ] PR description includes `Closes #<issue-number>`
- [ ] `flutter analyze` passes with no errors
- [ ] `dart format . --set-exit-if-changed` passes (no formatting diffs)
- [ ] No scratch files, debug prints, or commented-out code committed
- [ ] New features include tests where applicable

---

## 5. Commit Message Format

```
<type>(#<issue-number>): <short description>
```

**Types:** `feat`, `fix`, `docs`, `test`, `refactor`, `chore`

Examples:
```
feat(#42): add Stellar gift animation on live call screen
fix(#87): resolve auth session not persisting after restart
docs(#104): add CONTRIBUTING.md with full contributor guide
test(#61): add unit tests for mood log repository
```

---

## 6. Code Style

- **Architecture**: MVVM — keep views, viewmodels, and repositories separate
- **State management**: Riverpod only — no `setState` in feature screens
- **Formatting**: Run `dart format .` before committing
- **Lint**: No global lint suppressions (`// ignore_for_file`) without prior discussion
- **Naming**: Follow Dart naming conventions (`lowerCamelCase` for variables, `UpperCamelCase` for classes)
- **Imports**: Use relative imports within features, package imports across features

---

## 7. Local Supabase Setup

See [supabase/README.md](supabase/README.md) for full instructions on starting local Supabase, running migrations, and setting edge function secrets.

Quick start:
```bash
supabase start   # starts local Postgres, Auth, Storage, Studio
supabase db reset  # apply all migrations
```

---

## 8. Continuous integration

On top of the existing checks (formatting, analysis, unit/widget tests, Supabase
tests, Playwright), `.github/workflows/flutter-build.yml` compiles the app for a
real platform on pull requests that touch `lib/`, `pubspec.*`, `android/` or
`web/`:

| Job | What it proves | When |
| --- | --- | --- |
| `Build web` | `flutter build web --release` succeeds (web-only breakage) | every matching PR/push |
| `Build Android APK` | `flutter build apk --debug` succeeds (Gradle, manifest, plugin registration); the APK is uploaded as an artifact | every matching PR/push |
| `Build iOS without signing` | `flutter build ios --no-codesign` succeeds | weekly (Mon 04:00 UTC) and on demand |

The iOS job is intentionally not on every PR — a macOS runner costs roughly ten
times the minutes of Linux, and contributions have no signing story — so it runs
on a schedule and via *Run workflow* instead. All jobs can be started manually
from the Actions tab; `build-web` and `build-android` can also be dispatched for
a quick check without opening a PR.

Dependency updates are automated in `.github/dependabot.yml`: weekly grouped PRs
for `pub` (root), `npm` (`frontend/` and `server/`), and `github-actions`, capped
at five open PRs each so the queue stays reviewable.
