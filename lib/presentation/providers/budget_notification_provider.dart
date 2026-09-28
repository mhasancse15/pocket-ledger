import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/budget_notification_service.dart';
import '../../core/services/local_notification_service.dart';
import '../providers/database_provider.dart';
import 'preferences_provider.dart';

final budgetNotificationServiceProvider = Provider<BudgetNotificationService>((
  ref,
) {
  return BudgetNotificationService(
    database: ref.watch(databaseProvider),
    notifications: LocalNotificationService.instance,
  );
});

Future<void> reportBudgetNotificationCheck(Ref ref) {
  return _reportBudgetNotificationCheck(
    awaitPreferences: () =>
        ref.read(preferencesNotifierProvider.notifier).ready,
    readPreferences: () => ref.read(preferencesNotifierProvider),
    readService: () => ref.read(budgetNotificationServiceProvider),
  );
}

Future<void> reportWidgetBudgetNotificationCheck(WidgetRef ref) {
  return _reportBudgetNotificationCheck(
    awaitPreferences: () =>
        ref.read(preferencesNotifierProvider.notifier).ready,
    readPreferences: () => ref.read(preferencesNotifierProvider),
    readService: () => ref.read(budgetNotificationServiceProvider),
  );
}

Future<void> _reportBudgetNotificationCheck({
  required Future<void> Function() awaitPreferences,
  required Map<String, dynamic> Function() readPreferences,
  required BudgetNotificationService Function() readService,
}) async {
  try {
    await awaitPreferences();
    final preferences = readPreferences();

    await readService().checkCurrentMonth(
      budgetNotificationsEnabled:
          preferences['budgetNotificationsEnabled'] as bool? ?? false,
      targetNotificationsEnabled:
          preferences['monthlyTargetNotificationsEnabled'] as bool? ?? false,
    );
  } catch (error, stackTrace) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'budget notifications',
        context: ErrorDescription(
          'while checking current budget notification thresholds',
        ),
      ),
    );
  }
}
