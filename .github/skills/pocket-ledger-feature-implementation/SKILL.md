---
name: pocket-ledger-feature-implementation
description: Implement an end-to-end Pocket Ledger feature from a clear request or approved design. Use when the user asks to build, add, or wire up a feature in this Flutter app.
---

# Pocket Ledger feature implementation

Deliver a working, focused feature integrated into the existing app. Do not stop at a proposal when the user asked for implementation.

## Before editing

1. Read `.github/copilot-instructions.md` and inspect the nearest existing implementation across UI, state, storage, and routes.
2. Check `git status` and preserve all pre-existing work. Do not revert unrelated changes.
3. Turn the request into observable behavior. If a significant user-facing or data-model decision is unresolved, ask one focused question before implementing it.
4. Search for existing helpers, providers, models, styles, and route names before adding new ones.

## Implementation sequence

1. Make the smallest cohesive vertical slice: data/domain only if needed, state wiring, UI, and route/entry point.
2. For persisted features, wire the full path from Drift schema and migration through model/repository/provider to the screen. Preserve all existing data.
3. For derived data, use existing transaction/category/budget sources where possible; avoid duplicating state that can drift.
4. After mutations, invalidate or update every provider that feeds affected screens and summaries.
5. Surface save/delete errors and success feedback using existing app patterns. Do not swallow errors or show success before persistence succeeds.
6. Cover validation, loading, error, empty, confirmation, and cancellation behavior relevant to the feature.
7. Add or update focused tests for business rules and important state behavior when test infrastructure permits.

## Boundaries

- Do not refactor unrelated screens or migrate existing architecture as part of feature work.
- Do not add remote services, tracking, permissions, or dependencies without explicit need and user approval.
- Do not edit generated files by hand. Regenerate code using existing project tooling.
- Avoid unsafe casts, silent defaults that hide errors, broad catches, and side effects during widget build.
- Match established naming, formatting, Riverpod 2, GoRouter, Drift, and theme conventions.

## Handoff

Summarize what changed and identify any incomplete behavior or unresolved issue directly. Keep the final response concise and do not claim tests/builds that were not run.
