# Pocket Ledger - Clean Architecture + MVVM Guide

## Project Structure

```
lib/
├── config/                 # App configuration
│   ├── routes/            # GoRouter navigation
│   └── theme/             # Theme configuration
├── core/                  # Core utilities
│   ├── errors/            # Failures and Exceptions
│   ├── utils/             # Helper functions
│   └── extensions/        # Dart extensions
├── data/                  # Data Layer
│   ├── datasources/       # Local & Remote data sources
│   ├── models/            # Data models (with serialization)
│   └── repositories/      # Repository implementations
├── domain/                # Domain Layer (Business Logic)
│   ├── entities/          # Domain entities (pure Dart)
│   ├── repositories/      # Repository interfaces
│   └── usecases/          # Use cases (business rules)
└── presentation/          # Presentation Layer (UI)
    ├── pages/             # Full-screen pages
    ├── providers/         # Riverpod providers
    ├── viewmodels/        # MVVM ViewModels
    └── widgets/           # Reusable widgets
```

## Key Technologies

- **State Management**: Flutter Riverpod (reactive, compile-safe)
- **Database**: Drift (ORM for SQLite)
- **Routing**: GoRouter (declarative routing)
- **Architecture**: Clean Architecture + MVVM
- **Code Generation**: Build Runner (Freezed, JSON serialization)

## Data Flow

```
UI (Widgets/Pages)
    ↓
ViewModel (Riverpod Notifier)
    ↓
Use Cases (Business Logic)
    ↓
Repositories (Data Abstraction)
    ↓
Data Sources (Drift Database)
```

## Development Workflow

1. Define domain entities and use cases first
2. Create Drift database tables and DAOs
3. Implement repository pattern
4. Build ViewModels with Riverpod
5. Design UI widgets and pages
6. Write tests for each layer

