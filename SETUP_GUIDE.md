# Pocket Ledger - Complete Setup & Implementation Guide

## Quick Start

### 1. Install Dependencies
```bash
cd /Users/bs-support/pocket_ledger
flutter pub get
```

### 2. Generate Code
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### 3. Run on Device/Emulator
```bash
flutter run
```

---

## Project Architecture Overview

### Clean Architecture Layers

```
┌─────────────────────────────────┐
│   Presentation Layer (UI)       │
│  Pages, ViewModels, Widgets     │
└────────────────┬────────────────┘
                 │
┌────────────────▼────────────────┐
│    Domain Layer (Business)      │
│ Entities, UseCases, Interfaces  │
└────────────────┬────────────────┘
                 │
┌────────────────▼────────────────┐
│     Data Layer (Storage)        │
│  Models, Repositories, Sources  │
└────────────────┬────────────────┘
                 │
┌────────────────▼────────────────┐
│   Infrastructure (Drift/SQLite) │
│       Local Database            │
└─────────────────────────────────┘
```

### Data Flow (MVVM + Riverpod)

```
User Interaction
    ↓
ViewModel (StateNotifier)
    ↓
Use Cases (Business Logic)
    ↓
Repository Interface (Abstraction)
    ↓
Repository Implementation
    ↓
Data Sources (Drift Database)
    ↓
SQLite Local Storage
```

---

## Key Features (Phase 1 MVP)

### ✅ Dashboard
- Monthly budget status with progress indicator
- Current vs previous month comparison
- Today's transactions list
- Quick action buttons (Add Expense/Income)

### ✅ Add/Edit Transactions
- Form validation (amount > 0)
- Category selection (9 default categories)
- Payment method selection (6 methods)
- Optional note field (max 250 chars)
- Recurring expense option

### ✅ Categories
- 9 Predefined categories (Food, Transport, etc.)
- Custom category creation
- Category icon/color assignment
- Archive functionality

### ✅ Transaction History
- Filter by month
- Filter by category
- Sort by date
- Edit/Delete actions
- Pagination support

### ✅ Monthly Expense Limit
- Set limit per month
- Visual progress indicator
- Budget warning thresholds:
  - < 75%: On Track (Green)
  - 75-89%: Warning (Yellow)
  - 90-99%: Critical (Orange)
  - ≥ 100%: Exceeded (Red)

### ✅ Local Storage (Drift/SQLite)
- Offline-first architecture
- Automatic date queries
- Indexed searches
- Database migrations

---

## Technology Stack

| Layer | Technology | Purpose |
|-------|-----------|---------|
| State Management | Flutter Riverpod | Reactive state, compile-safe |
| Navigation | GoRouter | Declarative routing, deep linking |
| Database | Drift + SQLite | Type-safe ORM, offline storage |
| Charts | FL Charts | Beautiful data visualization |
| Export | CSV, PDF | Data portability |
| Build | build_runner | Code generation (Freezed, JSON) |

---

## Project Structure

```
lib/
├── main.dart                      # App entry point
├── config/
│   ├── routes/
│   │   └── app_router.dart       # GoRouter configuration
│   └── theme/
│       └── app_theme.dart        # Theme data & colors
├── core/
│   ├── errors/
│   │   ├── failures.dart         # Failure types for error handling
│   │   └── exceptions.dart       # Exception types
│   ├── extensions/
│   │   └── datetime_ext.dart     # DateTime utilities
│   └── utils/
│       └── constants.dart        # App constants
├── data/
│   ├── datasources/
│   │   └── drift/
│   │       ├── database.dart     # Drift database setup
│   │       └── tables.dart       # Table definitions
│   ├── models/
│   │   ├── transaction_model.dart
│   │   ├── category_model.dart
│   │   └── monthly_limit_model.dart
│   └── repositories/
│       ├── transaction_repository_impl.dart
│       ├── category_repository_impl.dart
│       └── limit_repository_impl.dart
├── domain/
│   ├── entities/
│   │   ├── transaction.dart      # ✓ Created
│   │   ├── category.dart         # ✓ Created
│   │   ├── monthly_limit.dart    # ✓ Created
│   │   └── recurring_rule.dart   # ✓ Created
│   ├── repositories/
│   │   ├── transaction_repository.dart  # ✓ Created
│   │   ├── category_repository.dart
│   │   └── limit_repository.dart
│   └── usecases/
│       ├── add_transaction_usecase.dart     # ✓ Created
│       ├── update_transaction_usecase.dart
│       ├── delete_transaction_usecase.dart
│       ├── get_transactions_usecase.dart
│       ├── set_monthly_limit_usecase.dart
│       ├── search_transactions_usecase.dart
│       └── export_transactions_usecase.dart
└── presentation/
    ├── pages/
    │   ├── dashboard_page.dart
    │   ├── add_transaction_page.dart
    │   ├── transactions_page.dart
    │   ├── monthly_history_page.dart
    │   ├── reports_page.dart
    │   ├── categories_page.dart
    │   ├── settings_page.dart
    │   └── recurring_expenses_page.dart
    ├── providers/
    │   ├── database_provider.dart
    │   ├── transaction_provider.dart
    │   ├── category_provider.dart
    │   └── limit_provider.dart
    ├── viewmodels/
    │   ├── dashboard_viewmodel.dart
    │   ├── transaction_viewmodel.dart
    │   ├── category_viewmodel.dart
    │   └── limit_viewmodel.dart
    └── widgets/
        ├── budget_status_card.dart
        ├── transaction_item.dart
        ├── category_selector.dart
        ├── payment_method_selector.dart
        └── month_selector.dart
```

---

## Phase 1 MVP - Implementation Checklist

- [x] Project setup with dependencies
- [x] Core error handling (failures, exceptions)
- [x] Domain entities (Transaction, Category, MonthlyLimit, RecurringRule)
- [x] Repository interfaces
- [x] UseCase base and examples
- [x] DateTime extensions
- [ ] Drift database setup & tables
- [ ] Data layer models & mapping
- [ ] Repository implementations
- [ ] Riverpod providers
- [ ] ViewModels with state management
- [ ] Dashboard page
- [ ] Add/Edit transaction forms
- [ ] Transaction history & filtering
- [ ] Category management
- [ ] Monthly limit configuration
- [ ] GoRouter navigation setup
- [ ] Theme configuration (light/dark)
- [ ] Basic charts integration
- [ ] CSV export
- [ ] Unit tests
- [ ] Widget tests

---

## Development Commands

### Generate Code
```bash
# Generate all code (Drift, Freezed, JSON serialization)
flutter pub run build_runner build --delete-conflicting-outputs

# Watch for changes
flutter pub run build_runner watch --delete-conflicting-outputs
```

### Run Tests
```bash
flutter test
```

### Format & Analyze
```bash
flutter format .
flutter analyze
```

### Build Release
```bash
# Android
flutter build apk --release

# iOS
flutter build ios --release
```

---

## Database Schema (Drift)

### TransactionTable
- `id` (PK): String, unique transaction ID
- `type`: String, 'income' or 'expense'
- `amount`: Double, transaction amount
- `categoryId` (FK): Category reference
- `date`: DateTime, transaction date
- `paymentMethod`: String, payment method
- `note`: String?, optional note (max 250 chars)
- `recurringRuleId` (FK): Recurring rule reference, nullable
- `createdAt`: DateTime, creation timestamp
- `updatedAt`: DateTime, last update timestamp

### CategoryTable
- `id` (PK): String, unique category ID
- `name`: String, category name
- `type`: String, 'income' or 'expense'
- `icon`: String?, Material icon name
- `color`: String?, hex color code
- `isArchived`: Boolean, soft delete flag
- `createdAt`: DateTime, creation timestamp

### MonthlyLimitTable
- `id` (PK): String, unique limit ID
- `year`: Int, year of the limit
- `month`: Int, month (1-12)
- `amount`: Double, monthly budget limit
- `createdAt`: DateTime, creation timestamp
- `updatedAt`: DateTime, last update timestamp
- **Unique Constraint**: (year, month)

### RecurringRuleTable
- `id` (PK): String, unique rule ID
- `title`: String, recurring expense title
- `amount`: Double, recurring amount
- `categoryId` (FK): Category reference
- `paymentMethod`: String, payment method
- `frequency`: String, 'weekly'|'monthly'|'quarterly'|'yearly'
- `startDate`: DateTime, first occurrence
- `nextOccurrenceDate`: DateTime, next due date
- `endDate`: DateTime?, optional end date
- `isActive`: Boolean, active/inactive status
- `createdAt`: DateTime, creation timestamp
- `updatedAt`: DateTime, last update timestamp

---

## Key Calculation Rules

### Budget Status
```
Remaining Limit = Monthly Limit - Current Month Expense
Usage Percentage = (Current Month Expense / Monthly Limit) × 100
```

### Budget Status Thresholds
```
< 75%        → On Track (Green)
75% - 89%    → Warning (Yellow)
90% - 99%    → Critical (Orange)
≥ 100%       → Exceeded (Red)
```

### Monthly Totals
```
Monthly Income = SUM(transactions WHERE type='income' AND date IN [month_start, month_end])
Monthly Expense = SUM(transactions WHERE type='expense' AND date IN [month_start, month_end])
Monthly Balance = Monthly Income - Monthly Expense
```

### Previous Month Comparison
```
Difference = Current Month Expense - Previous Month Expense
Percentage Change = (Difference / Previous Month Expense) × 100
```

---

## Testing Strategy

### Unit Tests
- Calculation logic (budget status, comparisons)
- DateTime utilities
- UseCase business logic
- Model mapping

### Widget Tests
- Form validation
- Budget status indicator
- Transaction list rendering
- Filter functionality

### Integration Tests
- Add → Edit → Delete transaction flow
- Set limit → View budget status flow
- Filter → Search → Export flow

---

## Best Practices

### State Management
- Use Riverpod `StateNotifier` for mutable state
- Use `FutureProvider` for async operations
- Keep providers focused and composable
- Combine providers instead of creating mega-providers

### Error Handling
- Use `Either<Failure, T>` for functional error handling
- Map exceptions to domain failures in repositories
- Show user-friendly error messages in UI
- Log errors for debugging

### Database
- Use Drift's generated DAOs for type safety
- Index frequently queried columns
- Use transactions for multi-step operations
- Handle migration edge cases

### UI
- Separate stateful UI from business logic
- Use riverpod consumers for reactive updates
- Keep widgets small and focused
- Theme all colors consistently

---

## Deployment Checklist

- [ ] Update app version in `pubspec.yaml`
- [ ] Run `flutter pub upgrade` (check for breaking changes)
- [ ] Run full test suite
- [ ] Build release APK/IPA
- [ ] Test on real devices
- [ ] Prepare release notes
- [ ] Update app store listings
- [ ] Submit to Play Store / App Store

---

## Useful Resources

- **Flutter Documentation**: https://flutter.dev
- **Riverpod Guide**: https://riverpod.dev
- **Drift Documentation**: https://drift.simonbinder.eu
- **GoRouter Guide**: https://pub.dev/packages/go_router
- **FL Charts**: https://pub.dev/packages/fl_chart
- **Material Design 3**: https://m3.material.io

---

## Support & Troubleshooting

### Build Issues
```bash
# Clean build
flutter clean
flutter pub get
flutter pub run build_runner clean
flutter pub run build_runner build --delete-conflicting-outputs
```

### Database Issues
- Delete app data: `flutter run --debug --purge-persistent-cache`
- Check migrations in `database.dart`
- Verify table definitions match entity models

### State Management Issues
- Use Redux DevTools for Riverpod debugging
- Check provider dependencies
- Verify notifier state updates

---

## Next Steps

1. **Complete Drift Setup**: Generate database code, create DAOs
2. **Implement Repositories**: Map between models and entities
3. **Build ViewModels**: Create Riverpod providers for state management
4. **Design Pages**: Create all UI pages with proper layout
5. **Add Navigation**: Set up GoRouter with all routes
6. **Test Everything**: Write comprehensive tests
7. **Polish UI**: Fine-tune theme, animations, and UX
8. **Prepare Release**: Version bump, store listings, release notes

---

**Created**: 2026-09-23
**Project Location**: `/Users/bs-support/pocket_ledger`
**Flutter Version**: 3.47.2
**Dart Version**: 3.13.2
