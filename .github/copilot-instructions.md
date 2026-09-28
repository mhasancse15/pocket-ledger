# Pocket Ledger - AI project instructions

Pocket Ledger is a local-first Flutter personal-finance app. Before changing code, inspect the current implementation and nearby feature patterns; do not assume the architecture document describes every existing code path.

## Project facts

- Flutter/Dart app; SDK constraint is `^3.13.2` in `pubspec.yaml`.
- Riverpod 2 is used for state and dependency wiring, including `FutureProvider`, `StateNotifierProvider`, and `StateNotifier`.
- GoRouter owns navigation in `lib/config/routes/app_router.dart` and `app_routes.dart`.
- Drift/SQLite is the local database in `lib/data/datasources/drift/`.
- Main feature layers are `lib/domain/` (entities, repository contracts, use cases), `lib/data/` (Drift, models, repository implementations), and `lib/presentation/` (pages, providers, viewmodels, widgets).
- Existing features do not all follow the documented Clean Architecture + MVVM flow consistently. Follow the closest working feature rather than refactoring unrelated code to enforce an idealized architecture.
- Existing finance data is private and local. Do not add network services, analytics, or remote syncing unless the user explicitly requests them.
- The app displays Bangladeshi Taka (BDT/৳), supports dark mode, and bundles Noto Sans Bengali fonts. Respect currency and Bengali text rendering in relevant UI.
- There is currently no `test/` directory. Check for tests before relying on them; add targeted tests for new pure business logic or critical behavior where practical.

## Working rules

- For a feature request, trace its UI, provider/viewmodel, repository, and database interactions before editing. Search for an existing equivalent and reuse it.
- Keep changes focused. Preserve existing data and UX; ask before making significant product or data-model choices that the request leaves open.
- For persistent schema changes, update Drift table definitions and schema version/migrations, preserve old user data, and regenerate generated code with the repository's existing build-runner workflow. Do not hand-edit generated files.
- Keep state reactive: after mutations, invalidate or update every affected provider so all relevant screens refresh.
- Keep errors visible through existing error/result patterns; do not silently swallow failures or show success when persistence failed.
- Use theme colors and component conventions, support light and dark themes, and include loading, error, empty, and success states where relevant.
- Do not add dependencies, architecture layers, comments, or documentation without a concrete need. Keep Dart types explicit and avoid unnecessary casts.
- Validate with the narrowest existing command that covers the change, usually `flutter analyze` and any relevant tests. Do not claim checks that were not run.
