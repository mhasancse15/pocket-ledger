import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config/routes/app_router.dart';
import 'config/theme/app_theme.dart';
import 'core/services/local_notification_service.dart';
import 'presentation/providers/budget_notification_provider.dart';
import 'presentation/providers/preferences_provider.dart';
import 'presentation/providers/recurring_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalNotificationService.instance.initialize();

  runApp(const ProviderScope(child: PocketLedgerApp()));
}

class PocketLedgerApp extends ConsumerStatefulWidget {
  const PocketLedgerApp({super.key});

  @override
  ConsumerState<PocketLedgerApp> createState() => _PocketLedgerAppState();
}

class _PocketLedgerAppState extends ConsumerState<PocketLedgerApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      LocalNotificationService.instance.setNotificationTapHandler(
        AppRouter.openNotification,
      );
      unawaited(reportWidgetBudgetNotificationCheck(ref));
      unawaited(_processRecurringExpenses());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_processRecurringExpenses());
    }
  }

  Future<void> _processRecurringExpenses() async {
    try {
      await ref.read(recurringProcessorControllerProvider).processDueRules();
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'recurring expenses',
          context: ErrorDescription('while processing due recurring expenses'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode =
        ref.watch(preferencesNotifierProvider)['isDarkMode'] as bool? ?? false;
    return MaterialApp.router(
      title: 'Pocket Ledger',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
      routerConfig: AppRouter.router,
      debugShowCheckedModeBanner: false,
    );
  }
}
