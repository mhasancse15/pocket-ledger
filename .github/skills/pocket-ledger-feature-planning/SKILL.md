---
name: pocket-ledger-feature-planning
description: Plan a new Pocket Ledger feature before implementation. Use when a request needs product clarification, requirements, user flows, acceptance criteria, edge cases, or a feature design proposal.
---

# Pocket Ledger feature planning

Create a concise, buildable feature brief grounded in this repository. Do not modify code unless the user also asks for implementation.

## Process

1. Read `.github/copilot-instructions.md`, `ARCHITECTURE.md`, and the closest existing feature files. Treat the architecture guide as intent, not proof that every feature follows it.
2. Identify the user problem, the intended user, and what outcome the feature should enable. Tie the proposal to the app's local-first personal-finance use case.
3. Describe the smallest useful scope and the primary user flow, including entry point, key actions, and completion feedback.
4. Define observable acceptance criteria, validation rules, loading/error/empty states, and important boundary cases.
5. Identify privacy, financial-data integrity, accessibility, localization/currency, and light/dark theme considerations that apply.
6. Sketch affected areas by existing repository paths: presentation, providers/viewmodels, domain, persistence, navigation, settings/export, and tests as appropriate. Do not assume every feature needs every layer.
7. Call out decisions that materially affect behavior or stored data. Ask one focused clarification at a time when the request cannot safely be resolved from existing app behavior. Otherwise state reasonable assumptions.

## Output

Provide:

- **Problem and proposed outcome**
- **Scope and user flow**
- **Acceptance criteria**
- **Data and architecture impact**
- **Risks and unresolved decisions**

Keep it short and actionable. Prefer incremental changes over unrelated redesigns. Do not invent cloud accounts, subscriptions, financial advice, or external integrations unless requested.
