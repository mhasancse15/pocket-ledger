import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PreferencesStore {
  Future<SharedPreferences> get _preferences => SharedPreferences.getInstance();

  Future<Map<String, dynamic>> load() async {
    final preferences = await _preferences;
    return {
      'isDarkMode': preferences.getBool('isDarkMode') ?? false,
      'currencySymbol': preferences.getString('currencySymbol') ?? '৳',
      'currencyCode': preferences.getString('currencyCode') ?? 'BDT',
      'dateFormat': preferences.getString('dateFormat') ?? 'yyyy-MM-dd',
      'budgetNotificationsEnabled':
          preferences.getBool('budgetNotificationsEnabled') ?? false,
      'monthlyTargetNotificationsEnabled':
          preferences.getBool('monthlyTargetNotificationsEnabled') ?? false,
    };
  }

  Future<void> setDarkMode(bool value) => _setBool('isDarkMode', value);

  Future<void> setBudgetNotificationsEnabled(bool value) =>
      _setBool('budgetNotificationsEnabled', value);

  Future<void> setMonthlyTargetNotificationsEnabled(bool value) =>
      _setBool('monthlyTargetNotificationsEnabled', value);

  Future<void> _setBool(String key, bool value) async {
    final saved = await (await _preferences).setBool(key, value);
    if (!saved) throw StateError('Unable to save the $key preference.');
  }

  Future<bool> isDarkMode() async =>
      (await _preferences).getBool('isDarkMode') ?? false;

  Future<String> getCurrencySymbol() async =>
      (await _preferences).getString('currencySymbol') ?? '৳';

  Future<String> getCurrencyCode() async =>
      (await _preferences).getString('currencyCode') ?? 'BDT';

  Future<String> getDateFormat() async =>
      (await _preferences).getString('dateFormat') ?? 'yyyy-MM-dd';
}

final preferencesRepositoryProvider = Provider((ref) => PreferencesStore());

final darkModeProvider = FutureProvider<bool>((ref) {
  return ref.watch(preferencesRepositoryProvider).isDarkMode();
});

final currencySymbolProvider = FutureProvider<String>((ref) {
  return ref.watch(preferencesRepositoryProvider).getCurrencySymbol();
});

class PreferencesNotifier extends StateNotifier<Map<String, dynamic>> {
  PreferencesNotifier(this._store)
    : super({
        'isDarkMode': false,
        'currencySymbol': '৳',
        'budgetNotificationsEnabled': false,
        'monthlyTargetNotificationsEnabled': false,
      }) {
    ready = _load();
  }

  final PreferencesStore _store;
  late final Future<void> ready;

  Future<void> _load() async {
    state = await _store.load();
  }

  Future<void> setDarkMode(bool value) async {
    await ready;
    await _store.setDarkMode(value);
    state = {...state, 'isDarkMode': value};
  }

  Future<void> setBudgetNotificationsEnabled(bool value) async {
    await ready;
    await _store.setBudgetNotificationsEnabled(value);
    state = {...state, 'budgetNotificationsEnabled': value};
  }

  Future<void> setMonthlyTargetNotificationsEnabled(bool value) async {
    await ready;
    await _store.setMonthlyTargetNotificationsEnabled(value);
    state = {...state, 'monthlyTargetNotificationsEnabled': value};
  }
}

final preferencesNotifierProvider =
    StateNotifierProvider<PreferencesNotifier, Map<String, dynamic>>((ref) {
      return PreferencesNotifier(ref.watch(preferencesRepositoryProvider));
    });
