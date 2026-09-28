---
name: pocket-ledger-architecture
description: Design or change Pocket Ledger feature architecture across Riverpod, domain, repositories, Drift persistence, and GoRouter. Use when a feature adds data, business logic, providers, navigation, or changes multiple layers.
---

# Pocket Ledger architecture

Design changes to fit the code that exists today. Inspect a similar implemented feature before choosing a pattern.

## Repository map

- `lib/domain/entities/`: business entities, commonly immutable and `Equatable`.
- `lib/domain/repositories/`: repository contracts.
- `lib/domain/usecases/`: business actions when useful and consistent with the feature.
- `lib/data/datasources/drift/tables.dart`: Drift table declarations.
- `lib/data/datasources/drift/database.dart`: database registration, schema version, migrations, and queries.
- `lib/data/datasources/drift/database.g.dart`: generated output; regenerate rather than editing.
- `lib/data/models/`: conversion between stored rows and domain objects.
- `lib/data/repositories/`: repository implementations.
- `lib/presentation/providers/`: Riverpod wiring, reads, and mutation state.
- `lib/presentation/viewmodels/`: existing presentation actions where the feature uses them.
- `lib/presentation/pages/` and `widgets/`: screens and reusable UI.
- `lib/config/routes/app_router.dart` and `app_routes.dart`: route registration and names.

## Design workflow

1. Trace a comparable feature end-to-end, including how it reports errors and refreshes dependent providers.
2. Choose only the layers required by the feature. Preserve local project conventions; do not force a wholesale migration to Clean Architecture/MVVM.
3. Keep business rules independent from widgets where practical. Use domain entities/contracts and repository implementations when the new persistent capability merits them.
4. Keep presentation state in Riverpod using the existing Riverpod 2 patterns. Prefer parameterized providers for keyed/derived reads where that matches nearby code.
5. Keep persistence operations behind the Drift database/repository patterns in use. Keep UI and widget state out of data access.
6. Register new screens with GoRouter and use existing route-name conventions. Avoid duplicating a route or feature entry point.
7. Trace mutation effects: list all dependent providers, totals, reports, dashboards, budgets, and export surfaces that must update.

## Persistence rules

- For a Drift schema change, update the table declaration and `AppDatabase.schemaVersion`; write an upgrade migration that preserves existing user data.
- Check constraints and uniqueness behavior; use conflict/upsert behavior intentionally and keep delete/update semantics explicit.
- Regenerate Drift output through the existing `build_runner` command. Never manually edit generated code.
- Preserve date/time semantics, currency precision/amount validation, and references to existing category/transaction identifiers.
- Do not clear, silently rewrite, or migrate user data destructively.

## Decision rules

- Do not add a use-case class or a new abstraction only to satisfy a diagram; add one when it improves isolation, reuse, or testability.
- Reuse shared entities, helpers, providers, and styles after searching for existing equivalents.
- Keep financial records local unless remote storage is explicitly requested.
- If a new model, schema migration, or interaction has multiple reasonable semantics, ask before choosing. Explain the options in user terms.
