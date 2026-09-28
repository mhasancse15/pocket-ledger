---
name: pocket-ledger-ui-design
description: Design or implement Pocket Ledger Flutter screens and interactions. Use when a feature changes UI, navigation entry points, forms, charts, cards, or responsive/accessibility behavior.
---

# Pocket Ledger UI design

Build clear, trustworthy finance UI that fits the current app and works in both light and dark themes.

## Before designing

1. Inspect `lib/config/theme/app_theme.dart` and nearby pages/widgets; use existing components, spacing, shapes, and patterns where possible.
2. Check how the feature is reached through the dashboard, bottom navigation, settings, or existing detail pages. Avoid adding redundant navigation.
3. Identify the primary action and present amounts, dates, categories, and status in a way users can scan without ambiguity.

## Design requirements

- Use `Theme.of(context)` and `colorScheme` for adaptable colors; do not hard-code a light-only palette.
- Format money consistently with the existing BDT/৳ presentation and use `intl` formatting patterns already in the app.
- Make text, controls, and layouts usable at narrow widths and with larger text. Avoid overflow-prone fixed widths.
- Use meaningful labels and tooltips for icon-only controls; provide accessible tap targets and don't communicate state by color alone.
- Forms must validate input before saving, preserve entered values on validation failure, and prevent invalid amounts/dates.
- Show clear loading, error, empty, and success feedback. Empty states should explain the next useful action.
- For filter/sheet interactions, commit user choices when the user confirms, update state immediately, and keep cancellation from changing applied filters.
- Use confirmation for destructive actions and explain the affected data.
- Consider Bengali-capable font rendering where Bengali strings are used. Preserve the app's existing hard-coded string conventions unless localization is specifically requested.
- Avoid decorative complexity that competes with balances or transaction details.

## Implementation

- Prefer existing reusable widgets and callbacks; keep screen-specific widgets private when consistent with neighboring code.
- Keep business calculations outside rendering code when they are reused or have meaningful edge cases.
- Do not introduce a design-system package, dependency, or global redesign for one feature.
- Verify all affected states and relevant routes; include both theme modes when a behavior depends on color or contrast.
