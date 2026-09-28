import 'package:flutter_test/flutter_test.dart';
import 'package:my_wallet/presentation/providers/preferences_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'dashboard sections default to visible and persist visibility changes',
    () async {
      final store = PreferencesStore();
      final initial = await store.load();

      expect(initial[DashboardSection.balance.preferenceKey], isTrue);
      expect(initial[DashboardSection.savingsGoals.preferenceKey], isTrue);

      await store.setDashboardSectionVisible(
        DashboardSection.categorySummary,
        false,
      );

      final updated = await store.load();
      expect(updated[DashboardSection.categorySummary.preferenceKey], isFalse);
      expect(updated[DashboardSection.balance.preferenceKey], isTrue);
    },
  );
}
