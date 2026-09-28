# Pocket Ledger

Pocket Ledger is an offline-first personal finance app built with Flutter. It helps you record income and expenses, understand spending over time, and plan monthly budgets. Your financial records are stored locally on your device using SQLite; the app does not require an account or internet connection for its core features.

The app uses Bangladeshi Taka (BDT, ৳) and supports light and dark themes.

## Features

### Dashboard

- View income, expenses, and balance for a selected month.
- Review today's transactions for the current month or recent transactions for another month.
- See monthly target progress and use quick actions to add income or expenses.
- Navigate between months and open the full transaction list.

### Transactions

- Add income or expense transactions with an amount, category, date, payment method, and optional note.
- Validate amounts and transaction categories before saving.
- Browse transactions grouped by date.
- Search transaction notes and filter by month, date range, type, category, payment method, and amount range.
- View transaction details, edit a transaction, or delete it with confirmation.

### Categories

- Manage separate income and expense categories.
- Create and edit categories, search the category list, and archive categories that should no longer be used for new transactions.

### Monthly targets and budgets

- Set a monthly spending target and track progress from the dashboard.
- Create monthly, category, and payment-method budgets for a selected month.
- Review budget progress, remaining amounts, monthly summaries, and comparisons.
- Choose whether unused amounts roll over for supported budgets.

### Reports and history

- Review a selected month's expense totals, spending breakdown by category, and budget overview.
- Compare current and previous month expenses and see a year-to-date expense chart and summary insights.
- Browse monthly income, expenses, balance, and transaction counts in monthly history.

### Export

- Export filtered transaction data as CSV or PDF and share the generated file.
- Select the current month, a specific month, a custom date range, or all available transactions.
- Optionally filter exports by transaction type and category.

### Recurring expenses

- View saved recurring-expense rules, including their amount, frequency, and next occurrence.
- **Note:** The recurring-rule data and list are present, but creating recurring rules from the app is not implemented yet.

### Settings and data

- Switch between light and dark themes.
- See the app's BDT currency setting.
- Clear local app data after confirmation.
- Backup and restore is shown in Settings as coming soon; it is not currently available.

## Screens

| Screen | What it does |
| --- | --- |
| Dashboard | Monthly balance, target progress, recent activity, and quick actions |
| Transactions | Search, filter, browse, and open transaction details |
| Reports | Monthly spending analysis and category breakdown |
| Monthly history | Compare income, expenses, and balance by month |
| Expense summary | Compare months and review the yearly expense chart |
| Budget management | Create and review monthly, category, and payment-method budgets |
| Categories | Create, edit, search, and archive transaction categories |
| Recurring expenses | View stored recurring rules |
| Export data | Filter and share transaction exports in CSV or PDF |
| Settings | Theme, data management, and links to management screens |

## Technology

- **Flutter / Dart** for the application.
- **Riverpod 2** for reactive state and dependency wiring.
- **GoRouter** for navigation, including a stateful bottom-navigation shell.
- **Drift and SQLite** for local persistence and schema migrations.
- **fl_chart** for spending charts.
- **intl** for date and number formatting.
- **CSV, PDF, and share_plus** for export generation and sharing.

The code is organized into `domain`, `data`, and `presentation` areas with shared configuration and utilities under `lib/config` and `lib/core`. Existing features do not all use every layer in exactly the same way, so new work should follow the closest established implementation.

## Getting started

### Requirements

- Flutter SDK compatible with the Dart SDK constraint in `pubspec.yaml` (`^3.13.2`).
- An Android or iOS development environment and a device or emulator for running the app.

### Install and run

From the repository root:

```sh
flutter pub get
flutter run
```

### Analyze

```sh
flutter analyze
```

### Regenerate Drift code

When changing Drift table/database definitions, regenerate generated files instead of editing them manually:

```sh
dart run build_runner build --delete-conflicting-outputs
```

## Project layout

```text
lib/
├── config/
│   ├── routes/                 # GoRouter setup and route names
│   └── theme/                  # Light and dark Material themes
├── core/
│   ├── services/               # Export service
│   ├── utils/                  # Constants, formatting, and common helpers
│   ├── extensions/             # Shared extensions
│   └── errors/                 # Failure and exception types
├── data/
│   ├── datasources/drift/      # SQLite database, tables, generated Drift code
│   ├── models/                 # Storage/domain mapping
│   └── repositories/           # Repository implementations
├── domain/
│   ├── entities/               # Transactions, budgets, categories, and limits
│   ├── repositories/           # Repository contracts
│   └── usecases/               # Business actions
└── presentation/
    ├── pages/                  # App screens
    ├── providers/              # Riverpod providers and state
    ├── viewmodels/             # Presentation actions
    └── widgets/                # Reusable UI components
```

## Data and privacy

- Transaction, category, budget, limit, and recurring-rule records are stored in the app's local SQLite database.
- Core transaction tracking works offline.
- Clearing the local database permanently removes locally stored app data. There is currently no in-app backup/restore or cloud synchronization.

## Contributing

When adding a feature, inspect a similar screen and trace its UI, Riverpod state, repository, and database path before making changes. For persistent schema changes, update the Drift migration and regenerate generated code. Keep financial data local unless remote storage is explicitly requested, and validate changes with the narrowest relevant tests and `flutter analyze`.
