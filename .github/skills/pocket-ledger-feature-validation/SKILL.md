---
name: pocket-ledger-feature-validation
description: Validate or review a Pocket Ledger feature change for correctness, architecture integration, persistence safety, UI states, and regressions. Use after implementing a feature or when asked to review one.
---

# Pocket Ledger feature validation

Review the changed feature end-to-end, focusing on user-visible correctness and preservation of financial data.

## Review checklist

- Trace the normal path from entry point through page, providers/viewmodels, repository, and database where relevant.
- Check loading, errors, empty results, invalid input, cancellation, duplicate actions, and post-save refresh behavior.
- Confirm all dependent dashboard/report/budget/list surfaces receive fresh state after mutations.
- For storage changes, verify schema version, upgrade path, generated Drift code, and preservation of existing records.
- Check amounts, BDT formatting, date/time boundaries, category references, and sorting/grouping for financial correctness.
- Check light/dark theme, narrow screens, larger text, accessibility labels, destructive-action confirmation, and keyboard/sheet behavior where relevant.
- Check routing, back navigation, route parameters, and duplicate entry points.
- Look for stale state, unhandled futures, race conditions, silent failures, and changed behavior outside requested scope.
- Inspect the diff and distinguish new findings from pre-existing issues.

## Validation workflow

1. Inspect existing tests and project scripts before selecting commands.
2. Run the narrowest applicable tests, then `flutter analyze` for changed Dart code. Run code generation only when generated sources are affected.
3. If no test coverage exists for the changed behavior, state that plainly and recommend or add focused coverage when appropriate.
4. Report concrete defects first with file paths and concise explanations. Do not report unrelated style preferences as bugs.
5. Do not change code during a review-only request. If the user asked to implement fixes, make minimal targeted changes and validate them.
